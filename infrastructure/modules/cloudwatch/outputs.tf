output "log_group_names" {
  description = "Mapa nombre logico -> nombre real del log group creado."
  value       = { for name, lg in aws_cloudwatch_log_group.this : name => lg.name }
}

output "log_group_arns" {
  description = "Mapa nombre logico -> ARN del log group creado."
  value       = { for name, lg in aws_cloudwatch_log_group.this : name => lg.arn }
}
