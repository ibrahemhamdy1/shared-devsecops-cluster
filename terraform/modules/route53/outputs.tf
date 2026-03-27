output "primary_zone_id" {
  description = "Primary hosted zone ID"
  value       = var.create_primary_zone ? aws_route53_zone.primary[0].zone_id : null
}

output "primary_zone_name_servers" {
  description = "Primary zone name servers"
  value       = var.create_primary_zone ? aws_route53_zone.primary[0].name_servers : null
}

output "private_zone_id" {
  description = "Private hosted zone ID"
  value       = var.create_private_zone ? aws_route53_zone.private[0].zone_id : null
}

output "environment_zone_id" {
  description = "Environment subdomain zone ID"
  value       = var.create_environment_zone ? aws_route53_zone.environment[0].zone_id : null
}
