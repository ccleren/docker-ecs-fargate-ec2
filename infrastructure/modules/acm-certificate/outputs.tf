output "certificate_arn" {
  description = "ARN del certificado ACM validado, listo para el listener HTTPS del ALB."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
