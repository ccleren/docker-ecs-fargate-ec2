variable "name_prefix" {
  description = "Prefijo usado para nombrar los security groups."
  type        = string
  default     = "cloudpulse"
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los security groups."
  type        = string
}

variable "enable_workstation_sg" {
  description = "Si crear el security group opcional de acceso SSH para debugging. Desactivado por defecto."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "CIDR con acceso SSH cuando enable_workstation_sg = true. Nunca debe ser 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/32"
}

variable "tags" {
  description = "Tags comunes aplicadas a los security groups."
  type        = map(string)
  default     = {}
}
