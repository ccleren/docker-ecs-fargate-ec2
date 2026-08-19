output "zone_id" {
  description = "Zone ID de la hosted zone usada, necesario para la validacion DNS del certificado ACM."
  value       = local.zone_id
}

output "name_servers" {
  description = "Name servers de la hosted zone (solo si create_hosted_zone = true; hay que configurarlos en el registrador del dominio)."
  value       = var.create_hosted_zone ? aws_route53_zone.this[0].name_servers : null
}

output "record_fqdn" {
  description = "FQDN del registro Alias creado hacia el ALB."
  value       = aws_route53_record.alb_alias.fqdn
}
