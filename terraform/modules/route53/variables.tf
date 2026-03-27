variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_name" {
  description = "Primary domain name"
  type        = string
  default     = ""
}

variable "private_domain_name" {
  description = "Private domain name for internal services"
  type        = string
  default     = "internal.local"
}

variable "vpc_id" {
  description = "VPC ID for private hosted zone"
  type        = string
  default     = ""
}

variable "create_primary_zone" {
  description = "Whether to create primary public hosted zone"
  type        = bool
  default     = false
}

variable "create_private_zone" {
  description = "Whether to create private hosted zone"
  type        = bool
  default     = true
}

variable "create_environment_zone" {
  description = "Whether to create environment subdomain zone"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
