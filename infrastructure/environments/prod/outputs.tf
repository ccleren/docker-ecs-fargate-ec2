output "alb_dns_name" {
  description = "DNS name del ALB."
  value       = module.alb.dns_name
}

output "app_url" {
  description = "URL publica de CloudPulse."
  value       = "https://${var.domain_name}"
}

output "route53_name_servers" {
  description = "Name servers de la hosted zone (solo si create_hosted_zone = true). Configuralos en tu registrador de dominio."
  value       = module.route53.name_servers
}

output "ecr_repository_urls" {
  description = "URLs de los 3 repositorios ECR, usadas por el pipeline de CI/CD para el build y push de imagenes."
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS, usado por el pipeline de CI/CD para el force-new-deployment."
  value       = module.ecs_cluster.cluster_name
}

output "ecs_service_names" {
  description = "Nombres de los 3 servicios ECS, usados por el pipeline de CI/CD para el force-new-deployment."
  value       = module.ecs_services.service_names
}

output "vpc_id" {
  description = "ID de la VPC."
  value       = module.vpc.vpc_id
}
