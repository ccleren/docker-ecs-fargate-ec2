resource "aws_cloudwatch_log_group" "this" {
  for_each = toset(var.log_group_names)

  name              = each.value
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cluster_cpu_high" {
  alarm_name          = "${var.cluster_name}-cpu-high"
  alarm_description   = "CPU media del cluster ECS por encima del umbral"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_alarm_threshold
  evaluation_periods  = 3
  period              = 60
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
  tags          = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cluster_memory_high" {
  alarm_name          = "${var.cluster_name}-memory-high"
  alarm_description   = "Memoria media del cluster ECS por encima del umbral"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.memory_alarm_threshold
  evaluation_periods  = 3
  period              = 60
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.cluster_name
  }

  alarm_actions = var.alarm_actions
  ok_actions    = var.alarm_actions
  tags          = var.tags
}
