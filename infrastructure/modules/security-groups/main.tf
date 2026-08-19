resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Trafico publico HTTP/HTTPS hacia el ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS publico"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "ecs_instance" {
  name        = "${var.name_prefix}-ecs-instance-sg"
  description = "Trafico hacia contenedores/tareas ECS, unicamente desde el ALB"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Todo el trafico de contenedores, solo desde el ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-ecs-instance-sg"
  })
}

resource "aws_security_group" "workstation" {
  count       = var.enable_workstation_sg ? 1 : 0
  name        = "${var.name_prefix}-workstation-sg"
  description = "Acceso SSH puntual para debugging de las instancias EC2 del cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH restringido"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-workstation-sg"
  })
}
