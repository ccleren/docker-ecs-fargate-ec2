variable "domain_name" {
  description = "Dominio principal a certificar (ej. cloudpulse.example.com)."
  type        = string
}

variable "subject_alternative_names" {
  description = "Nombres alternativos adicionales para el certificado."
  type        = list(string)
  default     = []
}

variable "route53_zone_id" {
  description = "Zone ID de Route 53 donde crear los registros de validacion DNS."
  type        = string
}

variable "tags" {
  description = "Tags comunes aplicadas al certificado."
  type        = map(string)
  default     = {}
}
