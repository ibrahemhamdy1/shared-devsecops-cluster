# EKS Addons Module — gp3 storage classes + metrics-server

terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = ">= 2.0" }
    helm       = { source = "hashicorp/helm", version = ">= 2.0" }
  }
}

# ─── gp3 Storage Class (default) ─────────────────────────────────────────────

resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = { "storageclass.kubernetes.io/is-default-class" = "true" }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Delete"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
    kmsKeyId   = var.ebs_kms_key_id
  }
}

resource "kubernetes_storage_class" "gp3_retain" {
  metadata { name = "gp3-retain" }
  storage_provisioner    = "ebs.csi.aws.com"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
    kmsKeyId   = var.ebs_kms_key_id
  }
}

resource "kubernetes_annotations" "remove_gp2_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"
  metadata { name = "gp2" }
  annotations = { "storageclass.kubernetes.io/is-default-class" = "false" }
  force       = true
}

# ─── Metrics Server ──────────────────────────────────────────────────────────

resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_version

  set {
    name  = "replicas"
    value = "2"
  }
  set {
    name  = "podDisruptionBudget.enabled"
    value = "true"
  }
  set {
    name  = "podDisruptionBudget.minAvailable"
    value = "1"
  }
  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }
  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
  set {
    name  = "tolerations[0].effect"
    value = "PreferNoSchedule"
  }
  set {
    name  = "nodeSelector.role"
    value = "system"
  }
}
