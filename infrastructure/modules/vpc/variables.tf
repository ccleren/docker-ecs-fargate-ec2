variable "name_prefix" {
  description = "Prefijo usado para nombrar los recursos de red."
  type        = string
  default     = "cloudpulse"
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de 2 AZs donde se distribuyen las subredes públicas y privadas."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subredes públicas (una por AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subredes privadas (una por AZ)."
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "dhcp_domain_name" {
  description = "Domain name del DHCP Options Set."
  type        = string
  default     = "ec2.internal"
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos de red."
  type        = map(string)
  default     = {}
}
