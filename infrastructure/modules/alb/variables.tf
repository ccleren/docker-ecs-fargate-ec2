variable "name_prefix" {
  description = "Prefijo usado para nombrar los recursos del ALB."
  type        = string
  default     = "cloudpulse"
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los target groups."
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subredes publicas donde se ubica el ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID del security group del ALB."
  type        = string
}

variable "certificate_arn" {
  description = "ARN del certificado ACM validado, usado por el listener HTTPS."
  type        = string
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos del ALB."
  type        = map(string)
  default     = {}
}
