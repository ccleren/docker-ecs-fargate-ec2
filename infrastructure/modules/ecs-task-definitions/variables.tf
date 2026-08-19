variable "aws_region" {
  description = "Region de AWS, usada en la configuracion del driver de logs awslogs."
  type        = string
  default     = "us-east-1"
}

variable "execution_role_arn" {
  description = "ARN del ecsTaskExecutionRole, comun a las 3 task definitions."
  type        = string
}

variable "task_definitions" {
  description = <<-EOT
    Mapa de task definitions a crear, una por microservicio.
    launch_type debe ser "EC2" (network_mode bridge) o "FARGATE" (network_mode awsvpc).
  EOT
  type = map(object({
    image          = string
    launch_type    = string
    cpu            = number
    memory         = number
    container_port = number
    log_group      = string
  }))
}

variable "tags" {
  description = "Tags comunes aplicadas a las task definitions."
  type        = map(string)
  default     = {}
}
