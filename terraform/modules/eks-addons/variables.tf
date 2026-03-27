variable "ebs_kms_key_id" {
  description = "KMS key ID for EBS encryption in storage classes"
  type        = string
}

variable "metrics_server_version" {
  description = "Metrics server Helm chart version"
  type        = string
  default     = "3.12.2"
}
