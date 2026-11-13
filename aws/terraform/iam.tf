data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  argocd_service_accounts = [
    "argocd-application-controller",
    "argocd-applicationset-controller",
    "argocd-server",
  ]

  # Fixed names let the roles refer to each other without a dependency cycle.
  spoke_role_names = { for env in local.spokes : env => "tinyshop-argocd-${env}" }
  spoke_role_arns  = [for n in values(local.spoke_role_names) : "arn:aws:iam::${local.account_id}:role/${n}"]

  secrets_arn_prefix = "arn:aws:secretsmanager:${var.region}:${local.account_id}:secret:tinyshop"

  cluster_names = merge(
    { hub = module.hub.cluster_name },
    { for env, m in module.spoke : env => m.cluster_name },
  )
}

# region: management
# The management role. Pod Identity gives it to the three Argo CD service accounts.
module "argocd_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  name                 = "tinyshop-argocd-management"
  use_name_prefix      = false
  attach_custom_policy = true

  # It may do one thing: assume the spoke roles.
  policy_statements = [{
    sid       = "AssumeSpokeRoles"
    actions   = ["sts:AssumeRole", "sts:TagSession"]
    resources = local.spoke_role_arns
  }]

  associations = { for sa in local.argocd_service_accounts : sa => {
    cluster_name    = module.hub.cluster_name
    namespace       = "argocd"
    service_account = sa
  } }
}
# endregion

# region: spoke-roles
# One role per spoke. No permissions: it is only the principal of an access entry.
data "aws_iam_policy_document" "spoke_trust" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "AWS"
      identifiers = [module.argocd_pod_identity.iam_role_arn]
    }
  }
}

resource "aws_iam_role" "spoke" {
  for_each = local.spokes

  name               = local.spoke_role_names[each.key]
  assume_role_policy = data.aws_iam_policy_document.spoke_trust.json
}
# endregion

# Roles for the add-ons that Argo CD installs on every cluster.
# region: lbc-role
module "lbc_pod_identity" {
  for_each = local.cluster_names
  source   = "terraform-aws-modules/eks-pod-identity/aws"
  version  = "2.10.0"

  name                            = "${each.value}-lbc"
  use_name_prefix                 = false
  attach_aws_lb_controller_policy = true

  associations = { lbc = {
    cluster_name    = each.value
    namespace       = "kube-system"
    service_account = "aws-load-balancer-controller"
  } }
}
# endregion

# region: eso-role
module "eso_pod_identity" {
  for_each = local.cluster_names
  source   = "terraform-aws-modules/eks-pod-identity/aws"
  version  = "2.10.0"

  name                                  = "${each.value}-external-secrets"
  use_name_prefix                       = false
  attach_external_secrets_policy        = true
  external_secrets_secrets_manager_arns = ["${local.secrets_arn_prefix}/${each.key}/*"]

  associations = { eso = {
    cluster_name    = each.value
    namespace       = "external-secrets"
    service_account = "external-secrets"
  } }
}
# endregion
