output "url" {
  value = "https://${var.public_lb_dns_name}.${trim(var.public_lb_dns_zone, ".")}"
}

output "ecs_task_role_arn" {
  value = aws_iam_role.task_role.arn
}