locals {
  cluster_name         = reverse(split("/", var.ecs_cluster_arn))[0]
  account_id           = data.aws_caller_identity.current.account_id
  region               = data.aws_region.current.name
  needs_execution_role = (length(var.secrets_ssm_paths) > 0 ? true : false)
}

data "aws_iam_role" "ecs_role" {
  name = "ecsTaskExecutionRole"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  exposed_ports                = var.ports == [] ? (var.port == 0 ? [] : [var.port]) : var.ports
  dd_src_code_integration_tags = var.enable_datadog_src_code_integration ? { "git.commit.sha" = var.commit_sha, "git.repository_url" = var.repository_url } : {}

  default_env_vars = {
    DD_SERVICE                 = var.service_name
    DD_VERSION                 = var.app_version
    DD_ENV                     = lower(terraform.workspace)
    DD_TAGS                    = join(",", [for k, v in merge(local.dd_src_code_integration_tags, var.dd_tags) : format("%s:%s", k, v)])
    DD_RUNTIME_METRICS_ENABLED = tostring(var.enable_datadog_runtime_metrics)
  }

  main_task_env_vars = merge(local.default_env_vars, var.env_vars)


  main_task = [{
    essential : true,
    cpu : 0,
    image : var.image,
    name : var.task_name,
    networkMode : "awsvpc",
    mountPoints : [],
    stopTimeout : var.stop_timeout
    ulimits : (
      var.docker_ulimits == [] ?
      null :
      var.docker_ulimits
    ),
    dockerLabels : var.docker_labels,
    volumesFrom : (
      var.side_car_image == "" ?
      [] :
      [{
        sourceContainer : var.side_car_name,
        readOnly : true
      }]
    ),
    portMappings : [
      for p in local.exposed_ports : { containerPort : p, hostPort : p, protocol : "tcp" }
    ],
    command : var.command,
    environment : [
      for k, v in local.main_task_env_vars : { name : k, value : v }
    ],
    secrets : [
      for env_var, ssm_path in var.secrets_ssm_paths : { name : env_var, valueFrom : format("arn:aws:ssm:%s:%s:parameter%s", local.region, local.account_id, ssm_path) }
    ],
    logConfiguration : local.logConf,
    healthCheck : length(var.container_healthcheck_command) == 0 ? null : local.container_healthcheck
  }]

  container_healthcheck = {
    command     = var.container_healthcheck_command
    interval    = var.container_healthcheck_interval
    timeout     = var.container_healthcheck_timeout
    retries     = var.container_healthcheck_retries
    startPeriod = var.container_healthcheck_start_period
  }

  logConf = {
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
      dd_tags : join(",", [for k, v in merge({ version : var.app_version }, var.tags) : format("%s:%s", k, v)])
    }
  }

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

  fluentbit_task = [{
    essential : true,
    image : var.fluent_bit_image_tag,
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

  side_car_task = (
    var.side_car_image == "" ?
    [] :
    [{
      image : var.side_car_image,
      name : var.side_car_name,
      networkMode : "awsvpc"
    }]
  )

  datadog_agent_task = (
    var.enable_datadog_agent ?
    [{
      name : "datadog-agent",
      image : var.datadog_agent_image_tag,
      memory : var.datadog_agent_memory,
      cpu : 0,
      environment : [
        { name : "DD_API_KEY", value : var.datadog_api_key },
        { name : "DD_SITE", value : "datadoghq.eu" },
        { name : "ECS_FARGATE", value : "true" },
        { name : "DD_TAGS", value : join(" ", [for k, v in var.tags : format("%s:%s", k, v)]) },
        { name : "DD_APM_ENABLED", value : tostring(var.enable_datadog_agent_apm) },
        { name : "DD_APM_IGNORE_RESOURCES", value : join(",", var.datadog_apm_ignore_ressources) },
        { name : "DD_APM_NON_LOCAL_TRAFFIC", value : tostring(var.enable_datadog_non_local_apm) },
        { name : "DD_DOGSTATSD_NON_LOCAL_TRAFFIC", value : tostring(var.enable_datadog_dogstatsd_non_local_traffic) },
        { name : "DD_ENV", value : lower(terraform.workspace) },
        { name : "DD_LOGS_INJECTION", value : tostring(var.enable_datadog_logs_injection) },
        { name : "DD_SERVICE", value : var.service_name },
        { name : "DD_DOGSTATSD_MAPPER_PROFILES", value : var.datadog_mapper },
        { name : "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT", value : tostring(var.datadog_receiver_otlp_http_endpoint) }
      ],
      logConfiguration : var.collect_datadog_agent_logs ? {
        logDriver : "awsfirelens",
        options : {
          Name : "datadog",
          apikey : var.datadog_api_key,
          Host : "http-intake.logs.datadoghq.eu",
          TLS : "on",
          provider : "ecs",
          dd_service : var.service_name,
          dd_source : "datadog-agent",
          dd_message_key : "log",
          dd_tags : join(",", [for k, v in var.tags : format("%s:%s", k, v)])
        }
      } : null
    }] :
    []
  )

}

resource "aws_iam_role" "task_role" {
  name               = "${var.service_name}-${var.task_name}-${terraform.workspace}"
  assume_role_policy = file("${path.module}/policies/assume/ecs-tasks.json")
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "custom_policy" {
  for_each   = { for index, policy_arn in var.task_role_policies_arn : index => policy_arn }
  role       = aws_iam_role.task_role.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "ecs_exec_policy" {
  count  = var.enable_execute_command ? 1 : 0
  role   = aws_iam_role.task_role.name
  policy = file("${path.module}/policies/ecs_exec.json")
}

resource "aws_iam_role" "execution_role" {
  count               = (local.needs_execution_role ? 1 : 0)
  name                = "${var.service_name}-${var.task_name}-${terraform.workspace}-task-execution-role"
  assume_role_policy  = file("${path.module}/policies/assume/ecs-tasks.json")
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"]
}

resource "aws_iam_role_policy" "read-task-secrets" {
  count  = (length(var.secrets_ssm_paths) > 0 ? 1 : 0)
  name   = "${var.service_name}-${var.task_name}-${terraform.workspace}-secrets"
  role   = aws_iam_role.execution_role[0].id
  policy = templatefile("${path.module}/policies/read-task-secrets.tftpl", { region : local.region, account_id : local.account_id, ssm_parameters : values(var.secrets_ssm_paths) })
}

# task definition
resource "aws_ecs_task_definition" "task" {
  family                   = "${var.service_name}-${var.task_name}-${terraform.workspace}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = local.needs_execution_role ? aws_iam_role.execution_role[0].arn : data.aws_iam_role.ecs_role.arn
  task_role_arn            = aws_iam_role.task_role.arn

  cpu    = var.cpu
  memory = var.mem

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  # secrets could be fetched using special ECS mechanism
  ## https://docs.aws.amazon.com/AmazonECS/latest/developerguide/specifying-sensitive-data-parameters.html#secrets-envvar-parameters

  // container definition spec
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html
  container_definitions = jsonencode(
    flatten(
      [local.main_task, local.side_car_task, local.fluentbit_task, local.datadog_agent_task]
    )
  )

  tags = var.tags
}
