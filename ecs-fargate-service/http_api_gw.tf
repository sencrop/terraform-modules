# Network Load Balancer, in public zone
#   all these resources are enabled depending on var.enable_api_gw 

resource "aws_security_group" "nlb" {
  count = var.enable_api_gw ? 1 : 0

  name_prefix = "nlb-"
  description = "controls access to the NLB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol    = "tcp"
    from_port   = 0
    to_port     = 65535 //FIXME
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
resource "aws_security_group" "nlb_to_service" {
  count = var.enable_api_gw ? 1 : 0

  name_prefix = "task-"
  description = "inbound access from the NLB for ${var.service_name}"
  vpc_id      = var.vpc_id

  ingress {
    protocol        = "tcp"
    from_port       = var.port
    to_port         = var.port
    security_groups = [aws_security_group.nlb[0].id]
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

resource "aws_lb" "nlb" {
  count = var.enable_api_gw ? 1 : 0

  name_prefix        = "nlb-"
  internal           = true // TODO change ??
  load_balancer_type = "network"
  subnets            = var.lb_subnets
  tags               = var.tags
}

resource "aws_lb_target_group" "nlb" {
  count      = var.enable_api_gw ? 1 : 0
  depends_on = [aws_lb.nlb]

  name_prefix = "task-"
  port        = var.port
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

# Redirect all traffic from the NLB to the target group
resource "aws_lb_listener" "nlb" {
  count = var.enable_api_gw ? 1 : 0

  load_balancer_arn = aws_lb.nlb[0].id
  port              = var.port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.nlb[0].id
    type             = "forward"
  }
}

resource "aws_apigatewayv2_api" "foo" {
  count = var.enable_api_gw ? 1 : 0

  name          = var.api_gw_name
  protocol_type = "HTTP"
  target        = aws_lb.nlb[0].dns_name
  cors_configuration {
    allow_credentials = var.api_gw_cors_configuration.allow_credentials
    allow_headers     = var.api_gw_cors_configuration.allow_headers
    allow_methods     = var.api_gw_cors_configuration.allow_methods
    allow_origins     = var.api_gw_cors_configuration.allow_origins
    expose_headers    = var.api_gw_cors_configuration.expose_headers
    max_age           = var.api_gw_cors_configuration.max_age
  }

  tags = var.tags
}

