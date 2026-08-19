locals {
  is_fargate = { for name, td in var.task_definitions : name => td.launch_type == "FARGATE" }
}

resource "aws_ecs_task_definition" "this" {
  for_each = var.task_definitions

  family                   = "${each.key}def"
  requires_compatibilities = [each.value.launch_type]
  network_mode             = local.is_fargate[each.key] ? "awsvpc" : "bridge"
  cpu                      = tostring(each.value.cpu)
  memory                   = tostring(each.value.memory)
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = each.value.image
      essential = true
      cpu       = each.value.cpu
      memory    = each.value.memory

      portMappings = [
        {
          containerPort = each.value.container_port
          hostPort      = local.is_fargate[each.key] ? each.value.container_port : 0
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = each.value.log_group
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}
