output "state_bucket_name" {
  description = "Nombre del bucket S3 del remote state. Úsalo en el bloque backend de environments/prod/backend.tf."
  value       = aws_s3_bucket.terraform_state.id
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de locking. Úsalo en el bloque backend de environments/prod/backend.tf."
  value       = aws_dynamodb_table.terraform_locks.name
}
