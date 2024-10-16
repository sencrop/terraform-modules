output "url" {
  value = "https://${var.public_lb_dns_name}.${trim(var.public_lb_dns_zone, ".")}"
}

output "fullname" {
  value = "${var.public_lb_dns_name}.${trim(var.public_lb_dns_zone, ".")}"
}

output "alb_zone_id" {
  value = (var.enable_public_lb ? aws_alb.lb[0].zone_id : (var.enable_private_lb ? aws_alb.lb_priv[0].zone_id : ""))
}

output "alb_dns_name" {
  value = (var.enable_public_lb ? aws_alb.lb[0].dns_name : (var.enable_private_lb ? aws_alb.lb_priv[0].dns_name : ""))
}

output "alb_listener_arn" {
  value = (var.enable_public_lb ? aws_alb_listener.lb_priv[0].arn : (var.enable_private_lb ? aws_alb_listener.lb_priv[0].dns_name : ""))
}

output "ecs_task_role_arn" {
  value = aws_iam_role.task_role.arn
}

output "ecs_task_definition_arn" {
  value = aws_ecs_task_definition.task.arn
}