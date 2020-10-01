# Application Load Balancer, in public zone, with https endpoint and publing name
#   all these resources are enabled depending on var.enable_public_lb 

resource "aws_security_group" "lb" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix = "lb-"
  description = "controls access to the LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Incoming traffic to the service from LB
resource "aws_security_group" "lb_to_service" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix = "task-"
  description = "inbound access from the LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.port
    to_port         = var.port
    security_groups = [aws_security_group.lb[0].id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  // due to dependency bug https://github.com/hashicorp/terraform/issues/8617
  lifecycle {
    create_before_destroy = true
  }
}


# create LB
resource "aws_lb" "alb" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix     = "alb-"
  subnets         = var.lb_subnets
  security_groups = [aws_security_group.lb[0].id]

  tags = var.tags
}

resource "aws_lb_target_group" "alb" {
  count      = var.enable_public_lb ? 1 : 0
  depends_on = [aws_lb.alb]

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
}

# Route all traffic from the ALB endpoint to the target group
resource "aws_lb_listener" "alb" {
  count = var.enable_public_lb ? 1 : 0

  load_balancer_arn = aws_lb.alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.lb_certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.alb[0].arn
    type             = "forward"
  }
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
  records = [aws_lb.alb[0].dns_name]

  # terraform tends to mess with records destruction/recreation
  allow_overwrite = true
}