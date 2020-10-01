locals {
  # ecs_cluster_id is in arn format
  cluster_name = reverse(split("/", var.ecs_cluster_id))[0]
}

resource "aws_cloudwatch_log_group" "service_log" {
  count = (var.logs == "cloudwatch" ? 1 : 0)

  name              = "/ecs/${local.cluster_name}/${var.service_name}_task"
  retention_in_days = 3
  tags              = var.tags
}

data "aws_iam_role" "ecs_role" {
  name = "ecsTaskExecutionRole"
}

locals {
  main_task = [{
    essential : true,
    cpu : 0,
    image : var.image,
    name : var.service_name,
    networkMode : "awsvpc",
    mountPoints : [],
    ulimits : (
      var.docker_ulimits == [] ?
      null :
      var.docker_ulimits
    ),
    volumesFrom : (
      var.side_car_image == "" ?
      [] :
      [{
        sourceContainer : var.side_car_name,
        readOnly : true
      }]
    ),
    portMappings : (
      var.port == 0 ?
      [] :
      [{
        containerPort : var.port,
        hostPort : var.port,
        protocol : "tcp"
      }]
    ),
    command : var.command,
    environment : [
      for k, v in var.env_vars : { name : k, value : v }
    ],
    logConfiguration : local.logConf
  }]

  logConf = (
    var.logs == "cloudwatch" ?
    {
      logDriver : "awslogs",
      options : {
        awslogs-group : aws_cloudwatch_log_group.service_log[0].name,
        awslogs-region : "eu-central-1",
        awslogs-stream-prefix : "ecs"
      }
    } :
    {
      logDriver : "awsfirelens",
      options : {
        Name : "datadog",
        apikey : var.datadog_api_key,
        Host : "http-intake.logs.datadoghq.eu",
        TLS : "on",
        provider : "ecs",
        dd_service : var.service_name,
        dd_source : var.datadog_log_source,
        dd_message_key : "log",
        dd_tags : join(",", [for k, v in var.tags : format("%s:%s", k, v)])
      }
    }
  )

  firelensOptions = (
    var.logs_json ?
    {
      enable-ecs-log-metadata : "true", # must be string
      config-file-type : "file",
      config-file-value : "/fluent-bit/configs/parse-json.conf"
    } :
    {
      enable-ecs-log-metadata : "true" # must be string
    }
  )

  fluentbit_task = (
    var.logs == "cloudwatch" ?
    [] :
    [{
      essential : true,
      image : "amazon/aws-for-fluent-bit:latest",
      name : "log_router",
      firelensConfiguration : {
        type : "fluentbit",
        options : local.firelensOptions
      }
    }]
  )

  side_car_task = (
    var.side_car_image == "" ?
    [] :
    [{
      image : var.side_car_image,
      name : var.side_car_name,
      networkMode : "awsvpc"
    }]
  )

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
  container_definitions = jsonencode(
    flatten(
      [local.main_task, local.side_car_task, local.fluentbit_task]
    )
  )

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
    security_groups = concat(
      aws_security_group.lb_to_service[*].id,
      aws_security_group.nlb_to_service[*].id,
    var.additional_security_groups[*])
    subnets = var.task_subnets
  }

  health_check_grace_period_seconds = var.enable_public_lb ? var.healthcheck_grace_period : null

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  dynamic "load_balancer" {
    for_each = var.enable_public_lb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.alb[0].arn
      container_name   = var.service_name
      container_port   = var.port
    }
  }

  dynamic "load_balancer" {
    for_each = var.enable_api_gw ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.nlb[0].arn
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

