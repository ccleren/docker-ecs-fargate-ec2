variable "cluster_id" {
  description = "ID del cluster ECS."
  type        = string
}

variable "cluster_name" {
  description = "Nombre del cluster ECS, usado para construir el resource_id de Application Auto Scaling."
  type        = string
}

variable "ec2_capacity_provider_name" {
  description = "Nombre del Capacity Provider EC2, usado por los servicios con launch_type = EC2."
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subredes privadas, usadas por los servicios Fargate (network_configuration)."
  type        = list(string)
}

variable "ecs_instance_sg_id" {
  description = "ID del security group asignado a las tareas Fargate en modo awsvpc."
  type        = string
}

variable "alb_arn_suffix" {
  description = "Arn suffix del ALB, usado en el resource_label de las politicas de target tracking."
  type        = string
}

variable "services" {
  description = <<-EOT
    Mapa de servicios ECS a crear. launch_type debe ser "EC2" o "FARGATE".
  EOT
  type = map(object({
    task_definition_arn     = string
    container_port          = number
    target_group_arn        = string
    target_group_arn_suffix = string
    launch_type             = string
    desired_count           = number
  }))
}

variable "min_capacity" {
  description = "Numero minimo de tareas por servicio (Application Auto Scaling)."
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Numero maximo de tareas por servicio (Application Auto Scaling)."
  type        = number
  default     = 8
}

variable "request_count_target" {
  description = "Peticiones por target objetivo para la politica de target tracking (ALBRequestCountPerTarget)."
  type        = number
  default     = 1000
}

variable "scale_out_cooldown" {
  description = "Cooldown (segundos) tras un scale-out."
  type        = number
  default     = 10
}

variable "scale_in_cooldown" {
  description = "Cooldown (segundos) tras un scale-in."
  type        = number
  default     = 300
}

variable "tags" {
  description = "Tags comunes aplicadas a los servicios ECS."
  type        = map(string)
  default     = {}
}
