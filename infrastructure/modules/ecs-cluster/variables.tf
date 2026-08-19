variable "name_prefix" {
  description = "Prefijo usado para nombrar los recursos del cluster."
  type        = string
  default     = "cloudpulse"
}

variable "cluster_name" {
  description = "Nombre del cluster ECS."
  type        = string
  default     = "cloudpulse-cluster"
}

variable "enable_container_insights" {
  description = "Si activar Container Insights a nivel de cluster."
  type        = bool
  default     = true
}

variable "private_subnet_ids" {
  description = "IDs de las subredes privadas donde se lanzan las instancias EC2 del cluster."
  type        = list(string)
}

variable "ecs_instance_sg_id" {
  description = "ID del security group asignado a las instancias EC2 del cluster."
  type        = string
}

variable "instance_type" {
  description = "Tipo de instancia EC2 para el Capacity Provider EC2."
  type        = string
  default     = "t2.medium"
}

variable "asg_min_size" {
  description = "Tamano minimo del Auto Scaling Group de instancias EC2."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Tamano maximo del Auto Scaling Group de instancias EC2."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags comunes aplicadas a los recursos del cluster."
  type        = map(string)
  default     = {}
}
