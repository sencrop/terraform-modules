
# Incoming traffic to the service from LB
resource "aws_security_group" "lb_to_service" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix = "task-"
  description = "inbound access from public LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.port
    to_port         = var.port
    security_groups = [var.public_alb_sg_id, aws_security_group.lb[0].id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_target_group" "public_lb" {
  count      = var.enable_public_lb ? 1 : 0

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
  }

  deregistration_delay = var.deregistration_delay
  
  tags = var.tags
}

resource "aws_alb_listener" "public_lb_listener" {
  count = var.enable_public_lb ? 1 : 0

  load_balancer_arn = var.public_alb_arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.lb_certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.public_lb[0].arn
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "public_lb_listener" {
  count = var.enable_public_lb ? 1 : 0

  listener_arn = aws_alb_listener.public_lb_listener[0].arn
  
  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.public_lb[0].arn
  }

  condition {
    host_header {
      values = ["${var.public_lb_dns_name}.*"]
    }
  }

  tags = var.tags
}


data "aws_route53_zone" "public_lb_dns_zone" {
  count = var.enable_public_lb ? 1 : 0

  name         = var.public_lb_dns_zone
  private_zone = false
}

resource "aws_route53_record" "dns_record" {
  count = var.enable_public_lb ? 1 : 0

  zone_id = data.aws_route53_zone.public_lb_dns_zone[0].zone_id
  name    = var.public_lb_dns_name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.lb[0].dns_name]

  # terraform tends to mess with records destruction/recreation
  allow_overwrite = true
}