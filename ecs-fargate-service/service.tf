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

  mappings = var.ports == [] ? ( var.port == 0 ? [] : [var.port] ) : var.ports 
  
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
    portMappings : [
      for p in local.mappings : { containerPort : p, hostPort : p,   protocol : "tcp" }
    ],
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
      image : "public.ecr.aws/aws-observability/aws-for-fluent-bit:2.19.0",
      name : "log_router",
      firelensConfiguration : {
        type : "fluentbit",
        options : local.firelensOptions
      },
      // below are defaults to avoid updating resources for nothing 
      mountPoints  = [],
      portMappings = [],
      volumesFrom  = [],
      environment  = [],
      user         = "0",
      cpu          = 0
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

  availabilty_side_car_task = (
    var.availability_sidecar_enable == false ?
    [] :
    [{
      image : var.availability_sidecar_image,
      name : "availability-tools",
      networkMode : "awsvpc"
      environment : [
        { name : "IS_CONNECT_JMX", value : "true" },
        { name : "DD_ENV", value : lower(terraform.workspace) }
      ]
    }]
  )

  datadog_agent_task = (
    var.enable_datadog_agent ?
    [{
      name : "datadog-agent",
      image : "public.ecr.aws/datadog/agent:latest",
      memory : 256,
      cpu : 0,
      environment : [
        { name : "DD_API_KEY", value : var.datadog_api_key },
        { name : "DD_SITE", value : "datadoghq.eu" },
        { name : "ECS_FARGATE", value : "true" },
        { name : "DD_TAGS", value : join(" ", [for k, v in var.tags : format("%s:%s", k, v)]) },
        { name : "DD_APM_ENABLED", value : tostring(var.enable_datadog_agent_apm) },
        { name : "DD_APM_IGNORE_RESOURCES", value : join(",", var.datadog_apm_ignore_ressources)},
        { name : "DD_APM_NON_LOCAL_TRAFFIC", value : tostring(var.enable_datadog_non_local_apm) },
        { name : "DD_ENV", value : lower(terraform.workspace) },
        { name : "DD_LOGS_INJECTION", value : tostring(var.enable_datadog_logs_injection) },
        { name : "DD_SERVICE", value: var.service_name},
        { name : "DD_DOGSTATSD_MAPPER_PROFILES", value: var.datadog_mapper }
              ]
    }] :
    []
  )

}

resource "aws_iam_role" "task_role" {
  name = "${var.service_name}-${terraform.workspace}"
  assume_role_policy = jsonencode({
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
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  # When using a custom policy, you may encounter the following error:
  #   The "count" value depends on resource attributes that cannot be determined
  # I didn't find a way to fix this.
  # The workaround is to create the policy first (using tarraform apply -target=) 
  # then finalize the attachment to the service
  count = (var.task_role_policy_arn == null ? 0 : 1)

  role       = aws_iam_role.task_role.name
  policy_arn = var.task_role_policy_arn
}


# task definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.service_name}-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = data.aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  cpu    = var.cpu
  memory = var.mem


  # secrets could be fetched using special ECS mechanism
  ## https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-parameters.html#secrets-envvar-parameters

  // container definition spec
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
  container_definitions = jsonencode(
    flatten(
      [local.main_task, local.side_car_task, local.availabilty_side_car_task, local.fluentbit_task, local.datadog_agent_task]
    )
  )

  tags = var.tags
}

resource "aws_security_group" "service" {
  name_prefix = "svc-"
  description = "rules for service for ${var.service_name}"
  vpc_id      = var.vpc_id

  tags = var.tags
  lifecycle {
    create_before_destroy = true
  }
}

# service definition
resource "aws_ecs_service" "service" {
  count            = var.task_definition_only == true ? 0 : 1
  name             = var.service_name
  cluster          = var.ecs_cluster_id
  task_definition  = aws_ecs_task_definition.task.arn
  desired_count    = var.desired_tasks
  launch_type      = "FARGATE"
  platform_version = var.platform_version

  network_configuration {
    security_groups = concat(
      [aws_security_group.service.id], 
      var.additional_security_groups[*]
    )
    subnets         = var.task_subnets
  }

  health_check_grace_period_seconds = (var.enable_public_lb || var.enable_private_lb ) ? var.healthcheck_grace_period : null

  # Allow external changes without Terraform plan difference
  lifecycle {
    ignore_changes = [desired_count]
  }

  dynamic "load_balancer" {
    for_each = concat(aws_alb_target_group.lb[*].arn, aws_alb_target_group.lb_priv[*].arn)
    content {
      target_group_arn = load_balancer.value
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

  propagate_tags = "SERVICE"
  tags           = var.tags
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

