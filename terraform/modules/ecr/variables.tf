variable "project" {
  description = "Project name"
  type        = string
}

variable "repository_names" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting"
  type        = string
  default     = "IMMUTABLE"
}

variable "kms_key_arn" {
  description = "KMS key ARN for ECR encryption"
  type        = string
  default     = null
}

variable "max_image_count" {
  description = "Maximum number of images to keep per repository"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
