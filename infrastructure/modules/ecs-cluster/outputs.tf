output "cluster_id" {
  description = "ID del cluster ECS."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "Nombre del cluster ECS."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN del cluster ECS."
  value       = aws_ecs_cluster.this.arn
}

output "ec2_capacity_provider_name" {
  description = "Nombre del Capacity Provider EC2, usado por los servicios EC2 (web, status)."
  value       = aws_ecs_capacity_provider.ec2.name
}

output "ecs_instance_role_arn" {
  description = "ARN del rol IAM asumido por las instancias EC2 del cluster."
  value       = aws_iam_role.ecs_instance_role.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN del rol IAM de ejecucion de tareas, usado por las task definitions."
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group de instancias EC2 del cluster."
  value       = aws_autoscaling_group.ecs.name
}

output "autoscaling_group_arn" {
  description = "ARN del Auto Scaling Group de instancias EC2 del cluster."
  value       = aws_autoscaling_group.ecs.arn
}
