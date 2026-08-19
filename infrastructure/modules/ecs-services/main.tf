locals {
  is_fargate = { for name, svc in var.services : name => svc.launch_type == "FARGATE" }
}

resource "aws_ecs_service" "this" {
  for_each = var.services

  name            = each.key
  cluster         = var.cluster_id
  task_definition = each.value.task_definition_arn
  desired_count   = each.value.desired_count

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  dynamic "capacity_provider_strategy" {
    for_each = local.is_fargate[each.key] ? [] : [1]
    content {
      capacity_provider = var.ec2_capacity_provider_name
      weight            = 1
      base              = 0
    }
  }

  dynamic "capacity_provider_strategy" {
    for_each = local.is_fargate[each.key] ? [1] : []
    content {
      capacity_provider = "FARGATE"
      weight            = 1
      base              = 0
    }
  }

  dynamic "network_configuration" {
    for_each = local.is_fargate[each.key] ? [1] : []
    content {
      subnets          = var.private_subnet_ids
      security_groups  = [var.ecs_instance_sg_id]
      assign_public_ip = false
    }
  }

  load_balancer {
    target_group_arn = each.value.target_group_arn
    container_name   = each.key
    container_port   = each.value.container_port
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# ---------------------------------------------------------------------------
# Autoescalado a nivel de servicio (Application Auto Scaling)
# ---------------------------------------------------------------------------

resource "aws_appautoscaling_target" "this" {
  for_each = var.services

  service_namespace  = "ecs"
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "request_count" {
  for_each = var.services

  name               = "${each.key}-request-count-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.request_count_target
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${each.value.target_group_arn_suffix}"
    }
  }
}
