output "alb_sg_id" {
  description = "ID del security group del ALB."
  value       = aws_security_group.alb.id
}

output "ecs_instance_sg_id" {
  description = "ID del security group de las instancias/tareas ECS."
  value       = aws_security_group.ecs_instance.id
}

output "workstation_sg_id" {
  description = "ID del security group de workstation (null si no esta activado)."
  value       = var.enable_workstation_sg ? aws_security_group.workstation[0].id : null
}
