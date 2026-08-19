variable "aws_region" {
  description = "Region de AWS donde se despliega toda la infraestructura."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefijo usado para nombrar la mayoria de los recursos."
  type        = string
  default     = "cloudpulse"
}

variable "environment" {
  description = "Nombre del entorno, usado en tags."
  type        = string
  default     = "prod"
}

variable "availability_zones" {
  description = "2 AZs donde se distribuyen las subredes publicas y privadas."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# ---------------------------------------------------------------------------
# Dominio / DNS / TLS
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Dominio de ejemplo de CloudPulse (ej. cloudpulse.tudominio.com). Debe ser un dominio real que controles."
  type        = string
  default     = "cloudpulse.example.com"
}

variable "create_hosted_zone" {
  description = "Si crear una hosted zone nueva en Route 53 para domain_name. Si es false, se usa una zona ya existente."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Imagenes de contenedor
# ---------------------------------------------------------------------------

variable "image_tag" {
  description = "Tag de las imagenes Docker a desplegar. El pipeline de CI/CD lo sobreescribe con el SHA del commit; localmente usa latest."
  type        = string
  default     = "latest"
}

# ---------------------------------------------------------------------------
# Seguridad
# ---------------------------------------------------------------------------

variable "enable_workstation_sg" {
  description = "Si crear el security group opcional de acceso SSH para debugging."
  type        = bool
  default     = false
}

variable "allowed_ssh_cidr" {
  description = "CIDR con acceso SSH cuando enable_workstation_sg = true."
  type        = string
  default     = "0.0.0.0/32"
}

# ---------------------------------------------------------------------------
# Capacidad EC2 / autoescalado
# ---------------------------------------------------------------------------

variable "ec2_instance_type" {
  description = "Tipo de instancia EC2 del Capacity Provider EC2."
  type        = string
  default     = "t2.medium"
}

variable "ec2_asg_min_size" {
  description = "Tamano minimo del Auto Scaling Group de instancias EC2."
  type        = number
  default     = 2
}

variable "ec2_asg_max_size" {
  description = "Tamano maximo del Auto Scaling Group de instancias EC2."
  type        = number
  default     = 4
}

variable "service_min_capacity" {
  description = "Numero minimo de tareas por servicio ECS."
  type        = number
  default     = 2
}

variable "service_max_capacity" {
  description = "Numero maximo de tareas por servicio ECS."
  type        = number
  default     = 8
}

# ---------------------------------------------------------------------------
# CloudWatch
# ---------------------------------------------------------------------------

variable "cpu_alarm_threshold" {
  description = "Umbral de CPU (%) del cluster para disparar la alarma."
  type        = number
  default     = 80
}

variable "memory_alarm_threshold" {
  description = "Umbral de memoria (%) del cluster para disparar la alarma."
  type        = number
  default     = 80
}

variable "log_retention_days" {
  description = "Dias de retencion de los logs en CloudWatch."
  type        = number
  default     = 30
}
