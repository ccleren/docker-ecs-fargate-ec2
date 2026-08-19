variable "cluster_name" {
  description = "Nombre del cluster ECS, usado en las dimensiones de las alarmas."
  type        = string
}

variable "log_group_names" {
  description = "Nombres de los log groups a crear, uno por task definition."
  type        = list(string)
  default     = ["/ecs/webdef", "/ecs/statusdef", "/ecs/docsdef"]
}

variable "log_retention_days" {
  description = "Dias de retencion de los logs en CloudWatch."
  type        = number
  default     = 30
}

variable "cpu_alarm_threshold" {
  description = "Umbral de CPU (%) del cluster a partir del cual se dispara la alarma."
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Umbral de memoria (%) del cluster a partir del cual se dispara la alarma."
  type        = number
  default     = 80
}

variable "alarm_actions" {
  description = "ARNs (ej. topics SNS) a notificar cuando las alarmas cambien de estado. Vacio por defecto."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos de CloudWatch."
  type        = map(string)
  default     = {}
}
