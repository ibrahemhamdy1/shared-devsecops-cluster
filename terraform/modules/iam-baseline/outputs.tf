output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.name
}

output "eks_node_group_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_group.arn
}

output "eks_node_group_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = aws_iam_role.eks_node_group.name
}

output "cicd_pipeline_role_arn" {
  description = "ARN of the CI/CD pipeline role"
  value       = var.create_cicd_role ? aws_iam_role.cicd_pipeline[0].arn : null
}

output "devops_team_role_arn" {
  description = "ARN of the DevOps team role"
  value       = var.create_devops_role ? aws_iam_role.devops_team[0].arn : null
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver role (for Pod Identity)"
  value       = aws_iam_role.ebs_csi_driver.arn
}
