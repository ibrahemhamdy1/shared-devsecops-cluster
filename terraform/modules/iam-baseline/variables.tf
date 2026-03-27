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

variable "create_cicd_role" {
  description = "Whether to create CI/CD pipeline role"
  type        = bool
  default     = false
}

variable "cicd_trusted_principals" {
  description = "ARNs of principals allowed to assume CI/CD role"
  type        = list(string)
  default     = []
}

variable "cicd_external_id" {
  description = "External ID for CI/CD role assumption"
  type        = string
  default     = ""
}

variable "create_devops_role" {
  description = "Whether to create DevOps team role"
  type        = bool
  default     = false
}

variable "devops_trusted_principals" {
  description = "ARNs of principals allowed to assume DevOps role"
  type        = list(string)
  default     = []
}
