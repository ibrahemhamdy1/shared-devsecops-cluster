# KMS Module — Encryption keys for EBS, S3, Secrets, and EKS

data "aws_caller_identity" "current" {}

# ─── EBS Encryption Key ──────────────────────────────────────────────────────

resource "aws_kms_key" "ebs" {
  description             = "${var.project}-${var.environment} EBS encryption key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.ebs_key_policy.json

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-ebs"
    Purpose = "ebs-encryption"
  })
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/${var.project}-${var.environment}-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}

data "aws_iam_policy_document" "ebs_key_policy" {
  statement {
    sid    = "EnableRootAccountAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow EKS node role to use the key for EBS volume encryption (usage only, no admin)
  dynamic "statement" {
    for_each = length(var.ebs_key_admin_arns) > 0 ? [1] : []
    content {
      sid    = "AllowEBSKeyUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.ebs_key_admin_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"
      ]
      resources = ["*"]
    }
  }

  # Allow ASG service-linked role to directly use the key for EBS encryption
  # Per AWS docs: https://docs.aws.amazon.com/autoscaling/ec2/userguide/key-policy-requirements-EBS-encryption.html
  statement {
    sid    = "AllowASGServiceLinkedRoleKeyUsage"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions = [
      "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
      "kms:GenerateDataKey*", "kms:DescribeKey"
    ]
    resources = ["*"]
  }

  # Allow ASG service-linked role to create grants for persistent resources (EBS volumes)
  statement {
    sid    = "AllowASGServiceLinkedRoleGrant"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions = [
      "kms:CreateGrant"
    ]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

# ─── S3 Encryption Key ───────────────────────────────────────────────────────

resource "aws_kms_key" "s3" {
  description             = "${var.project}-${var.environment} S3 encryption key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-s3"
    Purpose = "s3-encryption"
  })
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project}-${var.environment}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ─── Secrets Encryption Key ──────────────────────────────────────────────────

resource "aws_kms_key" "secrets" {
  description             = "${var.project}-${var.environment} Secrets encryption key"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-secrets"
    Purpose = "secrets-encryption"
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/${var.project}-${var.environment}-secrets"
  target_key_id = aws_kms_key.secrets.key_id
}

# ─── EKS Envelope Encryption Key ─────────────────────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "${var.project}-${var.environment} EKS secrets envelope encryption"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.eks_key_policy.json

  tags = merge(var.tags, {
    Name    = "${var.project}-${var.environment}-eks"
    Purpose = "eks-envelope-encryption"
  })
}

data "aws_iam_policy_document" "eks_key_policy" {
  statement {
    sid    = "EnableRootAccountAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allow EKS cluster role to use this key for secrets envelope encryption
  dynamic "statement" {
    for_each = length(var.eks_cluster_role_arns) > 0 ? [1] : []
    content {
      sid    = "AllowEKSClusterRoleUsage"
      effect = "Allow"
      principals {
        type        = "AWS"
        identifiers = var.eks_cluster_role_arns
      }
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"
      ]
      resources = ["*"]
    }
  }
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.project}-${var.environment}-eks"
  target_key_id = aws_kms_key.eks.key_id
}
