locals {
  spokes = toset(["dev", "prod"])

  addons = {
    eks-pod-identity-agent = { before_compute = true }
    vpc-cni                = { before_compute = true }
    kube-proxy             = {}
    coredns                = {}
  }

  cluster_admin_policy = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

# region: hub
module "hub" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.29.0"

  name               = "tinyshop-hub"
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  addons             = local.addons

  # Terraform runs outside the VPC: only your CIDRs may reach the hub API server.
  endpoint_public_access                   = true
  endpoint_public_access_cidrs             = var.api_allowed_cidrs
  enable_cluster_creator_admin_permissions = true

  # The HA install of Argo CD needs at least three nodes (anti-affinity).
  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 3
      max_size       = 3
      desired_size   = 3
    }
  }
}
# endregion

module "spoke" {
  for_each = local.spokes
  source   = "terraform-aws-modules/eks/aws"
  version  = "21.29.0"

  name               = "tinyshop-${each.key}"
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
  addons             = local.addons

  # region: spoke-access
  # Private API server: only the hub's nodes may call it (port 443).
  security_group_additional_rules = {
    hub = {
      from_port                = 443
      to_port                  = 443
      source_security_group_id = module.hub.node_security_group_id
      description              = "Argo CD on the hub"
    }
  }

  # The only identity with access is the role Argo CD assumes (see iam.tf).
  access_entries = {
    argocd = {
      principal_arn = aws_iam_role.spoke[each.key].arn
      policy_associations = {
        admin = {
          policy_arn   = local.cluster_admin_policy
          access_scope = { type = "cluster" }
        }
      }
    }
  }
  # endregion

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 2
      max_size       = 4
      desired_size   = 2
    }
  }
}
