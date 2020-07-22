locals {
  # ecs_cluster_id is in arn format
  cluster_name = reverse(split("/", var.ecs_cluster_id))[0]
}

resource "aws_cloudwatch_log_group" "service_log" {
  name              = "/ecs/${local.cluster_name}/${var.service_name}_task"
  retention_in_days = 3
  tags              = var.tags
}

data "aws_iam_role" "ecs_role" {
  name = "ecsTaskExecutionRole"
}

locals {
  encoded_vars = jsonencode([
    for k in keys(var.env_vars) :
    {
      name : k,
      value : var.env_vars[k]
    }
  ])

  # TODO jsonencode of maps instead of string interpolation
  env_block     = "\"environment\": ${local.encoded_vars},"
  command_block = (var.command == "" ? "" : "\"command\": ${jsonencode(var.command)},")
  port_block = (var.port == 0 ? "" :
  "\"portMappings\": [{ \"containerPort\": ${var.port}, \"hostPort\": ${var.port},\"protocol\": \"tcp\" }],")

  volume_block = (var.side_car_image == "" ? "" :
    "\"volumesFrom\": [ { \"sourceContainer\": \"${var.side_car_name}\", \"readOnly\": true } ],"
  )

  ulimits_block = (var.docker_ulimits == [] ? "" : "\"ulimits\": ${jsonencode(var.docker_ulimits)},")

  side_car_task_def = <<EOF
, {
    "image": "${var.side_car_image}",
    "name": "${var.side_car_name}",
    "networkMode": "awsvpc"
  }
EOF

  side_car = (var.side_car_image == "" ? "" : local.side_car_task_def)
}

resource "aws_iam_role" "task_role" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "airflow" {
  count = var.task_role_policy_arn != "" ? 1 : 0

  role       = aws_iam_role.task_role.name
  policy_arn = var.task_role_policy_arn
}


# task definition
resource "aws_ecs_task_definition" "task" {
  depends_on = [aws_security_group.lb_to_service] # via ENI

  family                   = var.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  cpu    = var.cpu
  memory = var.mem


  # TODO get secrets using special ECS mechanism
  ## search "secret" in https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html


  // container definition spec
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
  container_definitions = <<EOF
[
  {
    "cpu": 0,
    "image": "${var.image}",
    "name": "${var.service_name}",
    "networkMode": "awsvpc",
    "mountPoints": [],
    ${local.ulimits_block}
    ${local.volume_block}
    ${local.port_block}
    ${local.command_block}
    ${local.env_block}
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
         "awslogs-group" : "${aws_cloudwatch_log_group.service_log.name}",
         "awslogs-region": "eu-central-1",
         "awslogs-stream-prefix": "ecs"
      }
    }
  }
  ${local.side_car}
]
EOF

  tags = var.tags
}

# service definition
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = var.desired_tasks
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = concat(aws_security_group.lb_to_service[*].id, var.additional_security_groups[*])
    subnets         = var.task_subnets
  }

  health_check_grace_period_seconds = var.enable_public_lb ? var.healthcheck_grace_period : null

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  dynamic "load_balancer" {
    for_each = var.enable_public_lb ? [1] : []
    content {
      target_group_arn = aws_alb_target_group.lb[0].arn
      container_name   = var.service_name
      container_port   = var.port
    }
  }

  dynamic "service_registries" {
    for_each = var.enable_local_discovery ? [1] : []
    content {
      registry_arn = aws_service_discovery_service.name[0].arn
    }
  }

  tags = var.tags
}


resource "aws_service_discovery_service" "name" {
  count = var.enable_local_discovery ? 1 : 0
  name  = var.local_discovery_service_name

  dns_config {
    namespace_id = var.discovery_namespace_id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    # reuse lb healtch check path & co. cf https://www.terraform.io/docs/providers/aws/r/service_discovery_service.html#health_check_config-1
    failure_threshold = 1
  }
}

