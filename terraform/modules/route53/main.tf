# Route 53 Module for DNS Zone Structure

resource "aws_route53_zone" "primary" {
  count   = var.create_primary_zone ? 1 : 0
  name    = var.domain_name
  comment = "${var.project} primary hosted zone"
  tags    = merge(var.tags, { Name = "${var.project}-${var.domain_name}" })
}

resource "aws_route53_zone" "private" {
  count   = var.create_private_zone ? 1 : 0
  name    = var.private_domain_name
  comment = "${var.project} private hosted zone for internal services"
  vpc { vpc_id = var.vpc_id }
  tags = merge(var.tags, { Name = "${var.project}-${var.private_domain_name}" })
}

resource "aws_route53_zone" "environment" {
  count   = var.create_environment_zone ? 1 : 0
  name    = "${var.environment}.${var.domain_name}"
  comment = "${var.project} ${var.environment} environment zone"
  tags    = merge(var.tags, { Name = "${var.project}-${var.environment}.${var.domain_name}" })
}

resource "aws_route53_record" "environment_ns" {
  count   = var.create_environment_zone && var.create_primary_zone ? 1 : 0
  zone_id = aws_route53_zone.primary[0].zone_id
  name    = "${var.environment}.${var.domain_name}"
  type    = "NS"
  ttl     = 300
  records = aws_route53_zone.environment[0].name_servers
}
