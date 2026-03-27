# Security Groups Baseline Module

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project}-${var.environment}-eks-cluster-"
  description = "Additional security group for EKS cluster control plane"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-eks-cluster" })
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project}-${var.environment}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-vpc-endpoints" })
  lifecycle { create_before_destroy = true }
}

resource "aws_security_group" "internal_alb" {
  name_prefix = "${var.project}-${var.environment}-internal-alb-"
  description = "Security group for internal ALBs"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.project}-${var.environment}-internal-alb" })
  lifecycle { create_before_destroy = true }
}
