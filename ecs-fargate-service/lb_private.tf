# Application Load Balancer, in private zone, with dsn name
#   all these resources are enabled depending on var.enable_private_lb 

data "aws_vpc" "vpc" {
  id = var.vpc_id
}

resource "aws_security_group" "lb_priv" {
  count = var.enable_private_lb ? 1 : 0

  name_prefix = "lb-"
  description = "controls access to the private LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  }

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    security_groups = var.lb_private_additional_security_groups
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Incoming traffic to the service from LB
resource "aws_security_group" "lb_priv_to_service" {
  count = var.enable_private_lb ? 1 : 0

  name_prefix = "task-"
  description = "inbound access from the private LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.enable_private_lb ? toset(concat(var.ports, [var.port])) : []
    content {
      protocol        = "tcp"
      from_port       = ingress.value
      to_port         = ingress.value
      security_groups = [aws_security_group.lb_priv[0].id]
    }
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

# create private LB
resource "aws_alb" "lb_priv" {
  count = var.enable_private_lb ? 1 : 0

  name_prefix     = "lbprv-"
  subnets         = var.lb_private_subnets
  security_groups = [aws_security_group.lb_priv[0].id]
  internal        = true
  idle_timeout    = var.private_lb_idle_timeout

  dynamic "access_logs" {
    for_each = var.private_lb_access_logs_bucket == "" ? [] : [1]
    content {
      bucket  = var.private_lb_access_logs_bucket
      prefix  = "${var.private_lb_dns_name}.${var.private_lb_dns_zone}"
      enabled = true
    }
  }

  tags = var.tags
}

resource "aws_alb_target_group" "lb_priv" {
  count      = var.enable_private_lb ? 1 : 0
  depends_on = [aws_alb.lb_priv]

  name_prefix = "task-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  load_balancing_algorithm_type = var.lb_algorithm_type

  health_check {
    path                = var.healthcheck_path
    port                = var.healthcheck_port
    interval            = var.healthcheck_interval
    timeout             = var.healthcheck_timeout
    matcher             = var.healthcheck_matcher
    unhealthy_threshold = var.healthcheck_unhealthy_threshold
  }

  deregistration_delay = var.deregistration_delay
}

# Route all traffic from the ALB endpoint to the target group
resource "aws_alb_listener" "lb_priv" {
  count = var.enable_private_lb ? 1 : 0

  load_balancer_arn = aws_alb.lb_priv[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.lb_priv[0].arn
    type             = "forward"
  }
}

data "aws_route53_zone" "private_lb_dns_zone" {
  count = var.enable_private_lb ? 1 : 0

  name         = var.private_lb_dns_zone
  private_zone = true
}

resource "aws_route53_record" "private_dns_record" {
  count = var.enable_private_lb ? 1 : 0

  zone_id = data.aws_route53_zone.private_lb_dns_zone[0].zone_id
  name    = var.private_lb_dns_name
  type    = "CNAME"
  ttl     = "300"
  records = [aws_alb.lb_priv[0].dns_name]

  # teerraform tends to mess with records destruction/recreation
  allow_overwrite = true
}
