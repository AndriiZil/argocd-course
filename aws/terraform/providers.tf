provider "aws" {
  region = var.region
}

# Terraform talks to the hub cluster only, and never to a spoke.
locals {
  hub_token_command = ["eks", "get-token", "--cluster-name", module.hub.cluster_name, "--region", var.region]
}

provider "helm" {
  kubernetes = {
    host                   = module.hub.cluster_endpoint
    cluster_ca_certificate = base64decode(module.hub.cluster_certificate_authority_data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = local.hub_token_command
    }
  }
}

provider "kubernetes" {
  host                   = module.hub.cluster_endpoint
  cluster_ca_certificate = base64decode(module.hub.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = local.hub_token_command
  }
}
