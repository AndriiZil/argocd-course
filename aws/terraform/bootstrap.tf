locals {
  argocd_dir = "${path.module}/../argocd"
}

locals {
  # What Argo CD needs to know about each cluster: where it is and how to log in.
  cluster_config = merge(
    { hub = {
      server = "https://kubernetes.default.svc"
      config = { tlsClientConfig = { insecure = false } }
    } },
    { for env, m in module.spoke : env => {
      server = m.cluster_endpoint
      config = {
        awsAuthConfig = {
          clusterName = m.cluster_name
          roleARN     = aws_iam_role.spoke[env].arn
        }
        tlsClientConfig = {
          insecure = false
          caData   = m.cluster_certificate_authority_data
        }
      }
    } },
  )
}

# region: argocd
# Terraform installs Argo CD once. The values files stay in Git.
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "10.18.0"

  values = [
    for f in ["values-hub.yaml", "values-alb.yaml", "values-day2.yaml"] :
    file("${local.argocd_dir}/${f}")
  ]

  depends_on = [module.hub, module.argocd_pod_identity]
}
# endregion

# A cluster Secret holds an address and a role name, not a token.
# The platform ApplicationSets read its labels and annotations.
# region: cluster-secrets
resource "kubernetes_secret_v1" "cluster" {
  for_each = local.cluster_config

  metadata {
    name      = "cluster-${local.cluster_names[each.key]}"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
      env                              = each.key
      platform                         = "true"
    }
    annotations = { region = var.region, vpcId = module.vpc.vpc_id }
  }

  data = {
    name   = local.cluster_names[each.key]
    server = each.value.server
    config = jsonencode(each.value.config)
  }

  depends_on = [helm_release.argocd]
}
# endregion

# region: root
# Terraform applies the root Application once. Argo CD takes over from there.
resource "helm_release" "root" {
  name       = "root"
  namespace  = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.8"

  values = [yamlencode({ applications = { root = merge(
    yamldecode(file("${local.argocd_dir}/root.yaml")).spec,
    { namespace = "argocd" },
  ) } })]

  depends_on = [kubernetes_secret_v1.cluster]
}
# endregion
