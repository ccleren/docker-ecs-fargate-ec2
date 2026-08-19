output "repository_urls" {
  description = "Mapa nombre de servicio -> URL del repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "Mapa nombre de servicio -> ARN del repositorio ECR."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
