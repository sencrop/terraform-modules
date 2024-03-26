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

  lifecycle {
    create_before_destroy = true
  }
}

# Incoming traffic to the service from LB
resource "aws_security_group" "lb_to_service" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix = "task-"
  description = "inbound access from the LB for ${var.service_name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.enable_public_lb ? toset(concat(var.ports, [var.port])) : []
    content {
      protocol        = "tcp"
      from_port       = ingress.value
      to_port         = ingress.value
      security_groups = [aws_security_group.lb[0].id]
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

# create LB
resource "aws_alb" "lb" {
  count = var.enable_public_lb ? 1 : 0

  name_prefix     = "alb-"
  subnets         = var.lb_subnets
  security_groups = [aws_security_group.lb[0].id]
  idle_timeout    = var.public_lb_idle_timeout

  dynamic "access_logs" {
    for_each = var.public_lb_access_logs_bucket == "" ? [] : [1]
    content {
      bucket  = var.public_lb_access_logs_bucket
      prefix  = "${var.public_lb_dns_name}.${var.public_lb_dns_zone}"
      enabled = true
    }
  }

  tags = var.tags
}

resource "aws_wafv2_web_acl_association" "web_acl_association_my_lb" {
  count        = var.enable_public_lb && var.waf_acl_arn != "" ? 1 : 0
  depends_on   = [aws_alb.lb]
  resource_arn = aws_alb.lb[0].arn
  web_acl_arn  = var.waf_acl_arn
}

resource "aws_alb_target_group" "lb" {
  count      = var.enable_public_lb ? 1 : 0
  depends_on = [aws_alb.lb]

  name_prefix = "task-"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  load_balancing_algorithm_type = var.lb_algorithm_type

  health_check {
    path     = var.healthcheck_path
    port     = var.healthcheck_port != "traffic-port" ? var.healthcheck_port : var.port
    interval = var.healthcheck_interval
    timeout  = var.healthcheck_timeout
    matcher  = var.healthcheck_matcher
  }

  deregistration_delay = var.deregistration_delay
}

# Route all traffic from the ALB endpoint to the target group
resource "aws_alb_listener" "lb" {
  count = var.enable_public_lb ? 1 : 0

  load_balancer_arn = aws_alb.lb[0].arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.lb_certificate_arn

  default_action {
    target_group_arn = aws_alb_target_group.lb[0].arn
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
  records = [aws_alb.lb[0].dns_name]

  # teerraform tends to mess with records destruction/recreation
  allow_overwrite = true
}
