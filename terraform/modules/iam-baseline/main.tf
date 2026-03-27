# IAM Baseline Module
# Separates: human access, CI/CD access, cluster access, workload access

# ─── EKS Cluster Role ────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.project}-${var.environment}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eks-cluster"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster.name
}

# ─── EKS Node Group Role ─────────────────────────────────────────────────────

resource "aws_iam_role" "eks_node_group" {
  name = "${var.project}-${var.environment}-eks-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-eks-node"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.eks_node_group.name
}

# ─── CI/CD Pipeline Role ─────────────────────────────────────────────────────

resource "aws_iam_role" "cicd_pipeline" {
  count = var.create_cicd_role ? 1 : 0
  name  = "${var.project}-${var.environment}-cicd-pipeline"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.cicd_trusted_principals
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.cicd_external_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-cicd-pipeline"
  })
}

resource "aws_iam_policy" "cicd_pipeline" {
  count       = var.create_cicd_role ? 1 : 0
  name        = "${var.project}-${var.environment}-cicd-pipeline"
  description = "CI/CD pipeline permissions - ECR push, EKS deploy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Sid    = "EKSAccess"
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "arn:aws:eks:*:*:cluster/${var.project}-${var.environment}-*"
      },
      {
        Sid    = "STSGetCallerIdentity"
        Effect = "Allow"
        Action = ["sts:GetCallerIdentity"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_pipeline" {
  count      = var.create_cicd_role ? 1 : 0
  policy_arn = aws_iam_policy.cicd_pipeline[0].arn
  role       = aws_iam_role.cicd_pipeline[0].name
}

# ─── DevOps Team Admin Role ──────────────────────────────────────────────────

resource "aws_iam_role" "devops_team" {
  count = var.create_devops_role ? 1 : 0
  name  = "${var.project}-${var.environment}-devops-team"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.devops_trusted_principals
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-devops-team"
  })
}

resource "aws_iam_policy" "devops_team" {
  count       = var.create_devops_role ? 1 : 0
  name        = "${var.project}-${var.environment}-devops-team"
  description = "DevOps team permissions - EKS admin, read-only infra"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EKSFullAccess"
        Effect = "Allow"
        Action = ["eks:*"]
        Resource = "arn:aws:eks:*:*:cluster/${var.project}-${var.environment}-*"
      },
      {
        Sid    = "EKSListAccess"
        Effect = "Allow"
        Action = ["eks:ListClusters", "eks:DescribeAddonVersions"]
        Resource = "*"
      },
      {
        Sid    = "ReadOnlyInfra"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "elasticloadbalancing:Describe*",
          "cloudwatch:Describe*",
          "cloudwatch:GetMetricData",
          "logs:Describe*",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "devops_team" {
  count      = var.create_devops_role ? 1 : 0
  policy_arn = aws_iam_policy.devops_team[0].arn
  role       = aws_iam_role.devops_team[0].name
}

# ─── EBS CSI Driver Role (Pod Identity) ──────────────────────────────────────

resource "aws_iam_role" "ebs_csi_driver" {
  name = "${var.project}-${var.environment}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = ["sts:AssumeRole", "sts:TagSession"]
        Effect    = "Allow"
        Principal = { Service = "pods.eks.amazonaws.com" }
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project}-${var.environment}-ebs-csi-driver"
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}
