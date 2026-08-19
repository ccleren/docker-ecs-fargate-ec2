output "service_names" {
  description = "Mapa nombre de servicio -> nombre real del servicio ECS."
  value       = { for name, svc in aws_ecs_service.this : name => svc.name }
}

output "service_ids" {
  description = "Mapa nombre de servicio -> ID del servicio ECS."
  value       = { for name, svc in aws_ecs_service.this : name => svc.id }
}
