terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = "cloudpulse"
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  log_groups = {
    web    = "/ecs/webdef"
    status = "/ecs/statusdef"
    docs   = "/ecs/docsdef"
  }
}

# ---------------------------------------------------------------------------
# Red
# ---------------------------------------------------------------------------

module "vpc" {
  source = "../../modules/vpc"

  name_prefix        = var.name_prefix
  availability_zones = var.availability_zones
  tags               = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix           = var.name_prefix
  vpc_id                = module.vpc.vpc_id
  enable_workstation_sg = var.enable_workstation_sg
  allowed_ssh_cidr      = var.allowed_ssh_cidr
  tags                  = local.common_tags
}

# ---------------------------------------------------------------------------
# ECR
# ---------------------------------------------------------------------------

module "ecr" {
  source = "../../modules/ecr"

  repository_names = ["web", "status", "docs"]
  tags             = local.common_tags
}

# ---------------------------------------------------------------------------
# DNS + TLS
#
# route53 crea/referencia la hosted zone y, en el mismo modulo, el registro
# Alias hacia el ALB. acm-certificate depende del zone_id de route53 para la
# validacion DNS; alb depende del certificado. No hay ciclo real: el registro
# Alias (dentro de route53) es el unico recurso que depende de outputs del
# ALB, y ni la zona ni el certificado dependen de el.
# ---------------------------------------------------------------------------

module "route53" {
  source = "../../modules/route53"

  domain_name        = var.domain_name
  create_hosted_zone = var.create_hosted_zone
  alb_dns_name       = module.alb.dns_name
  alb_zone_id        = module.alb.zone_id
  tags               = local.common_tags
}

module "acm_certificate" {
  source = "../../modules/acm-certificate"

  domain_name     = var.domain_name
  route53_zone_id = module.route53.zone_id
  tags            = local.common_tags
}

# ---------------------------------------------------------------------------
# ALB
# ---------------------------------------------------------------------------

module "alb" {
  source = "../../modules/alb"

  name_prefix       = var.name_prefix
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security_groups.alb_sg_id
  certificate_arn   = module.acm_certificate.certificate_arn
  tags              = local.common_tags
}

# ---------------------------------------------------------------------------
# ECS Cluster (EC2 + Fargate)
# ---------------------------------------------------------------------------

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name_prefix        = var.name_prefix
  cluster_name       = "${var.name_prefix}-cluster"
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_instance_sg_id = module.security_groups.ecs_instance_sg_id
  instance_type      = var.ec2_instance_type
  asg_min_size       = var.ec2_asg_min_size
  asg_max_size       = var.ec2_asg_max_size
  tags               = local.common_tags
}

# ---------------------------------------------------------------------------
# CloudWatch
# ---------------------------------------------------------------------------

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  cluster_name           = module.ecs_cluster.cluster_name
  log_group_names        = values(local.log_groups)
  log_retention_days     = var.log_retention_days
  cpu_alarm_threshold    = var.cpu_alarm_threshold
  memory_alarm_threshold = var.memory_alarm_threshold
  tags                   = local.common_tags
}

# ---------------------------------------------------------------------------
# Task Definitions
# ---------------------------------------------------------------------------

module "ecs_task_definitions" {
  source = "../../modules/ecs-task-definitions"

  aws_region         = var.aws_region
  execution_role_arn = module.ecs_cluster.ecs_task_execution_role_arn

  task_definitions = {
    web = {
      image          = "${module.ecr.repository_urls["web"]}:${var.image_tag}"
      launch_type    = "EC2"
      cpu            = 512
      memory         = 1024
      container_port = 80
      log_group      = module.cloudwatch.log_group_names["web"]
    }
    status = {
      image          = "${module.ecr.repository_urls["status"]}:${var.image_tag}"
      launch_type    = "EC2"
      cpu            = 512
      memory         = 1024
      container_port = 80
      log_group      = module.cloudwatch.log_group_names["status"]
    }
    docs = {
      image          = "${module.ecr.repository_urls["docs"]}:${var.image_tag}"
      launch_type    = "FARGATE"
      cpu            = 512
      memory         = 1024
      container_port = 80
      log_group      = module.cloudwatch.log_group_names["docs"]
    }
  }

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Services + autoescalado de servicio
# ---------------------------------------------------------------------------

module "ecs_services" {
  source = "../../modules/ecs-services"

  cluster_id                 = module.ecs_cluster.cluster_id
  cluster_name               = module.ecs_cluster.cluster_name
  ec2_capacity_provider_name = module.ecs_cluster.ec2_capacity_provider_name
  private_subnet_ids         = module.vpc.private_subnet_ids
  ecs_instance_sg_id         = module.security_groups.ecs_instance_sg_id
  alb_arn_suffix             = module.alb.alb_arn_suffix
  min_capacity               = var.service_min_capacity
  max_capacity               = var.service_max_capacity

  services = {
    web = {
      task_definition_arn     = module.ecs_task_definitions.task_definition_arns["web"]
      container_port          = 80
      target_group_arn        = module.alb.web_target_group_arn
      target_group_arn_suffix = module.alb.web_target_group_arn_suffix
      launch_type             = "EC2"
      desired_count           = 2
    }
    status = {
      task_definition_arn     = module.ecs_task_definitions.task_definition_arns["status"]
      container_port          = 80
      target_group_arn        = module.alb.status_target_group_arn
      target_group_arn_suffix = module.alb.status_target_group_arn_suffix
      launch_type             = "EC2"
      desired_count           = 2
    }
    docs = {
      task_definition_arn     = module.ecs_task_definitions.task_definition_arns["docs"]
      container_port          = 80
      target_group_arn        = module.alb.docs_target_group_arn
      target_group_arn_suffix = module.alb.docs_target_group_arn_suffix
      launch_type             = "FARGATE"
      desired_count           = 2
    }
  }

  tags = local.common_tags

  # El Capacity Provider EC2 debe estar asociado al cluster
  # (aws_ecs_cluster_capacity_providers, dentro de module.ecs_cluster) antes
  # de crear ningun servicio que lo referencie.
  depends_on = [module.ecs_cluster]
}
