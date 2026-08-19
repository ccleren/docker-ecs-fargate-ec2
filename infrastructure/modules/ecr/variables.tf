variable "repository_names" {
  description = "Nombres de los repositorios ECR a crear, uno por microservicio."
  type        = list(string)
  default     = ["web", "status", "docs"]
}

variable "max_image_count" {
  description = "Numero maximo de imagenes a retener por repositorio antes de purgar las mas antiguas."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags comunes aplicadas a los repositorios ECR."
  type        = map(string)
  default     = {}
}
