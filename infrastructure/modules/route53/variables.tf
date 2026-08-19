variable "domain_name" {
  description = "Dominio de ejemplo del proyecto (ej. cloudpulse.example.com)."
  type        = string
}

variable "create_hosted_zone" {
  description = "Si crear una hosted zone nueva en Route 53. Si es false, se usa una zona ya existente para domain_name."
  type        = bool
  default     = false
}

variable "alb_dns_name" {
  description = "DNS name del ALB, usado como target del registro Alias."
  type        = string
}

variable "alb_zone_id" {
  description = "Hosted Zone ID del ALB, requerido por el registro Alias."
  type        = string
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos de Route 53 (solo aplica si create_hosted_zone = true)."
  type        = map(string)
  default     = {}
}
