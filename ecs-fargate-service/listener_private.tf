
# Incoming traffic to the service from LB
resource "aws_security_group_rule" "lb_priv_to_service_ingress_shared_lb" {
  count = var.enable_private_lb ? 1 : 0
  security_group_id = aws_security_group.service.id
  type = "ingress"
  protocol        = "tcp"
  from_port       = var.port
  to_port         = var.port
  source_security_group_id = var.private_alb_sg_id
}

resource "aws_alb_target_group" "private_lb" {
  count      = var.enable_private_lb ? 1 : 0

  name_prefix = "task-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = var.healthcheck_path
    interval = var.healthcheck_interval
    timeout  = var.healthcheck_timeout
    matcher  = var.healthcheck_matcher
    unhealthy_threshold = var.healthcheck_unhealthy_threshold
  }

  deregistration_delay = var.deregistration_delay
  
  tags = var.tags
}

resource "aws_alb_listener" "private_lb" {
  count = var.enable_private_lb ? 1 : 0

  load_balancer_arn = var.private_alb_arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.private_lb[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "private_lb_listener" {
  count = var.enable_private_lb ? 1 : 0

  listener_arn = aws_alb_listener.private_lb[0].arn
  
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.private_lb[0].arn
  }

  condition {
    host_header {
      values = [
        trimsuffix("${var.private_lb_dns_name}.${var.private_lb_dns_zone}", ".")
      ]
    }
  }

  tags = var.tags
}

data "aws_route53_zone" "private_lb_dns_zone" {
  count = var.enable_private_lb ? 1 : 0

  name         = var.private_lb_dns_zone
  private_zone = true
}

data "aws_alb" "shared_private_lb" {
  count = var.enable_private_lb ? 1 : 0

  arn = var.private_alb_arn
}

resource "aws_route53_record" "private_dns_record" {
  count = var.enable_private_lb ? 1 : 0

  zone_id = data.aws_route53_zone.private_lb_dns_zone[0].zone_id
  name    = var.private_lb_dns_name
  type    = "CNAME"
  ttl     = "300"
  records = [data.aws_alb.shared_private_lb[0].dns_name]

  # terraform tends to mess with records destruction/recreation
  allow_overwrite = true
}