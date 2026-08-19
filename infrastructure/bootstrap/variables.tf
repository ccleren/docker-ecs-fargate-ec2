variable "aws_region" {
  description = "Región de AWS donde se crea el backend remoto."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nombre del bucket S3 que almacena el remote state de Terraform. Debe ser globalmente único."
  type        = string
  default     = "cloudpulse-terraform-state"
}

variable "lock_table_name" {
  description = "Nombre de la tabla DynamoDB usada para el locking del state."
  type        = string
  default     = "cloudpulse-terraform-locks"
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos del backend."
  type        = map(string)
  default = {
    Project     = "cloudpulse"
    ManagedBy   = "terraform"
    Environment = "bootstrap"
  }
}
