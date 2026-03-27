output "gp3_storage_class_name" {
  description = "Name of the default gp3 storage class"
  value       = kubernetes_storage_class.gp3.metadata[0].name
}

output "gp3_retain_storage_class_name" {
  description = "Name of the gp3-retain storage class"
  value       = kubernetes_storage_class.gp3_retain.metadata[0].name
}

output "metrics_server_status" {
  description = "Metrics server Helm release status"
  value       = helm_release.metrics_server.status
}
