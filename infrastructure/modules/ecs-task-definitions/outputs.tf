output "task_definition_arns" {
  description = "Mapa nombre de servicio -> ARN (con revision) de la task definition."
  value       = { for name, td in aws_ecs_task_definition.this : name => td.arn }
}

output "task_definition_families" {
  description = "Mapa nombre de servicio -> family de la task definition."
  value       = { for name, td in aws_ecs_task_definition.this : name => td.family }
}
