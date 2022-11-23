output "url" {
  value = "https://${var.public_lb_dns_name}.${trim(var.public_lb_dns_zone, ".")}"
}

output "alb_zone_id" {
  value = (var.enable_public_lb ? aws_alb.lb[0].zone_id : "")
}

output "alb_dns_name" {
  value = (var.enable_public_lb ? aws_alb.lb[0].dns_name : "")
}

output "ecs_task_role_arn" {
  value = aws_iam_role.task_role.arn
}