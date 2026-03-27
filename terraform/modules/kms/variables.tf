variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

variable "deletion_window_in_days" {
  description = "KMS key deletion window in days"
  type        = number
  default     = 30
}

variable "ebs_key_admin_arns" {
  description = "ARNs of IAM principals that can use the EBS KMS key"
  type        = list(string)
  default     = []
}

variable "eks_cluster_role_arns" {
  description = "ARNs of EKS cluster IAM roles that can use the EKS envelope encryption key"
  type        = list(string)
  default     = []
}
