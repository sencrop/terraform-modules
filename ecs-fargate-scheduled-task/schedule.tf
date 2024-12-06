resource "aws_cloudwatch_event_rule" "rule" {
  name                = "${var.service_name}-${var.task_name}-${terraform.workspace}"
  schedule_expression = "cron(${var.schedule})"
}

resource "aws_cloudwatch_event_target" "scheduled_task" {
  rule     = aws_cloudwatch_event_rule.rule.name
  arn      = var.ecs_cluster_arn
  role_arn = "arn:aws:iam::812957082909:role/ecsEventsRole"

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.task.arn
    launch_type         = "FARGATE"
    platform_version    = "1.4.0"
    network_configuration {
      subnets = var.task_subnets
    }
  }
}
