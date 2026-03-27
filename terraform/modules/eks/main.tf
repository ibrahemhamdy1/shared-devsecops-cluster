# EKS Cluster Module
# Pod Identity over IRSA | Karpenter deferred | AL2023 | IMDSv2 enforced

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 6.0" }
    tls = { source = "hashicorp/tls", version = ">= 4.0" }
  }
}

# ─── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.cluster_version
  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
    security_group_ids      = var.additional_security_group_ids
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      provider { key_arn = var.kms_key_arn }
      resources = ["secrets"]
    }
  }

  enabled_cluster_log_types = var.cluster_log_types

  access_config {
    authentication_mode                        = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  tags = merge(var.tags, { Name = var.cluster_name })
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# ─── OIDC Provider ───────────────────────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = merge(var.tags, { Name = "${var.cluster_name}-oidc" })
}

# ─── EKS Access Entries ──────────────────────────────────────────────────────

resource "aws_eks_access_entry" "this" {
  for_each      = var.access_entries
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  type          = each.value.type
}

resource "aws_eks_access_policy_association" "this" {
  for_each      = var.access_entries
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value.principal_arn
  policy_arn    = each.value.policy_arn
  access_scope {
    type       = each.value.access_scope_type
    namespaces = each.value.namespaces
  }
  depends_on = [aws_eks_access_entry.this]
}

# ─── Core EKS Addons ─────────────────────────────────────────────────────────

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.system]
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  tags                        = var.tags
  depends_on                  = [aws_eks_node_group.system, aws_eks_pod_identity_association.ebs_csi]
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = var.ebs_csi_driver_role_arn
  tags            = var.tags
}

# ─── System Node Group ───────────────────────────────────────────────────────

resource "aws_launch_template" "system" {
  name_prefix = "${var.cluster_name}-system-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.system_node_disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.cluster_name}-system", NodePool = "system" })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, { Name = "${var.cluster_name}-system", NodePool = "system" })
  }

  tags = var.tags
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-system"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.system_node_instance_types
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.system_node_desired
    max_size     = var.system_node_max
    min_size     = var.system_node_min
  }

  update_config { max_unavailable = 1 }

  labels = { role = "system", nodepool = "system" }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "PREFER_NO_SCHEDULE"
  }

  launch_template {
    id      = aws_launch_template.system.id
    version = aws_launch_template.system.latest_version
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-system", NodePool = "system" })
  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}

# ─── Tools Node Group ────────────────────────────────────────────────────────

resource "aws_launch_template" "tools" {
  name_prefix = "${var.cluster_name}-tools-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.tools_node_disk_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      kms_key_id            = var.ebs_kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, { Name = "${var.cluster_name}-tools", NodePool = "tools" })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, { Name = "${var.cluster_name}-tools", NodePool = "tools" })
  }

  tags = var.tags
}

resource "aws_eks_node_group" "tools" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-tools"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.tools_node_instance_types
  capacity_type   = "ON_DEMAND"
  ami_type        = "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = var.tools_node_desired
    max_size     = var.tools_node_max
    min_size     = var.tools_node_min
  }

  update_config { max_unavailable = 1 }

  labels = { role = "tools", nodepool = "tools" }

  launch_template {
    id      = aws_launch_template.tools.id
    version = aws_launch_template.tools.latest_version
  }

  tags = merge(var.tags, { Name = "${var.cluster_name}-tools", NodePool = "tools" })
  lifecycle { ignore_changes = [scaling_config[0].desired_size] }
}
