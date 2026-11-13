variable "region" {
  type        = string
  description = "AWS region. An example: pick your own."
  default     = "eu-central-1"
}

variable "kubernetes_version" {
  type        = string
  description = "EKS version for all three clusters."
  default     = "1.37"
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types of the node groups. An example: size them for your load."
  default     = ["m6i.large"]
}

variable "api_allowed_cidrs" {
  type        = list(string)
  description = "Who may reach the hub API server from the internet. No default on purpose."
}
