output "eks_cluster_sg_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "vpc_endpoints_sg_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

output "internal_alb_sg_id" {
  description = "Security group ID for internal ALBs"
  value       = aws_security_group.internal_alb.id
}
