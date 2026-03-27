variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.35"
}

variable "cluster_role_arn" {
  description = "IAM role ARN for EKS cluster"
  type        = string
}

variable "node_role_arn" {
  description = "IAM role ARN for EKS node groups"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for EKS cluster and node groups (private)"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public API endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDR blocks allowed to access public endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs for cluster"
  type        = list(string)
  default     = []
}

variable "kms_key_arn" {
  description = "KMS key ARN for envelope encryption of K8s secrets"
  type        = string
  default     = null
}

variable "ebs_kms_key_arn" {
  description = "KMS key ARN for EBS volume encryption"
  type        = string
  default     = null
}

variable "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI driver (Pod Identity)"
  type        = string
}

variable "cluster_log_types" {
  description = "EKS control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "access_entries" {
  description = "Map of EKS access entries"
  type = map(object({
    principal_arn     = string
    policy_arn        = string
    type              = optional(string, "STANDARD")
    access_scope_type = optional(string, "cluster")
    namespaces        = optional(list(string), null)
  }))
  default = {}
}

variable "system_node_instance_types" {
  description = "Instance types for system node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "system_node_desired" {
  type    = number
  default = 2
}

variable "system_node_min" {
  type    = number
  default = 2
}

variable "system_node_max" {
  type    = number
  default = 4
}

variable "system_node_disk_size" {
  description = "Disk size in GB for system nodes"
  type        = number
  default     = 50
}

variable "tools_node_instance_types" {
  description = "Instance types for tools node group"
  type        = list(string)
  default     = ["t3.large"]
}

variable "tools_node_desired" {
  type    = number
  default = 2
}

variable "tools_node_min" {
  type    = number
  default = 1
}

variable "tools_node_max" {
  type    = number
  default = 6
}

variable "tools_node_disk_size" {
  description = "Disk size in GB for tools nodes"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
