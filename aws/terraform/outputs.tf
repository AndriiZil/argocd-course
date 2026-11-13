output "hub_kubeconfig_command" {
  description = "Run this to reach the hub cluster with kubectl."
  value       = "aws eks update-kubeconfig --name ${module.hub.cluster_name} --region ${var.region}"
}
