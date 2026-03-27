output "ebs_key_arn" {
  description = "ARN of the EBS encryption KMS key"
  value       = aws_kms_key.ebs.arn
}

output "ebs_key_id" {
  description = "ID of the EBS encryption KMS key"
  value       = aws_kms_key.ebs.key_id
}

output "s3_key_arn" {
  description = "ARN of the S3 encryption KMS key"
  value       = aws_kms_key.s3.arn
}

output "s3_key_id" {
  description = "ID of the S3 encryption KMS key"
  value       = aws_kms_key.s3.key_id
}

output "secrets_key_arn" {
  description = "ARN of the Secrets encryption KMS key"
  value       = aws_kms_key.secrets.arn
}

output "secrets_key_id" {
  description = "ID of the Secrets encryption KMS key"
  value       = aws_kms_key.secrets.key_id
}

output "eks_key_arn" {
  description = "ARN of the EKS envelope encryption KMS key"
  value       = aws_kms_key.eks.arn
}

output "eks_key_id" {
  description = "ID of the EKS envelope encryption KMS key"
  value       = aws_kms_key.eks.key_id
}
