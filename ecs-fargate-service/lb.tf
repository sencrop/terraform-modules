# all there resources are obsolete, and will be removed once all services 
#   are using shared LBs


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
  count = var.enable_public_lb && var.waf_acl_arn != "" ? 1 : 0
  depends_on = [aws_alb.lb]
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

  health_check {
    path     = var.healthcheck_path
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

