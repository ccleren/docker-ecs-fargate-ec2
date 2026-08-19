output "alb_arn" {
  description = "ARN del ALB."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "Arn suffix del ALB, usado en el resource label de las politicas de autoescalado."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "DNS name del ALB."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Hosted Zone ID del ALB, para el registro Alias de Route 53."
  value       = aws_lb.this.zone_id
}

output "https_listener_arn" {
  description = "ARN del listener HTTPS (443)."
  value       = aws_lb_listener.https.arn
}

output "web_target_group_arn" {
  description = "ARN del target group del servicio web."
  value       = aws_lb_target_group.web.arn
}

output "status_target_group_arn" {
  description = "ARN del target group del servicio status."
  value       = aws_lb_target_group.status.arn
}

output "docs_target_group_arn" {
  description = "ARN del target group del servicio docs."
  value       = aws_lb_target_group.docs.arn
}

output "web_target_group_arn_suffix" {
  description = "Arn suffix del target group web, usado en el resource label de autoescalado."
  value       = aws_lb_target_group.web.arn_suffix
}

output "status_target_group_arn_suffix" {
  description = "Arn suffix del target group status, usado en el resource label de autoescalado."
  value       = aws_lb_target_group.status.arn_suffix
}

output "docs_target_group_arn_suffix" {
  description = "Arn suffix del target group docs, usado en el resource label de autoescalado."
  value       = aws_lb_target_group.docs.arn_suffix
}
