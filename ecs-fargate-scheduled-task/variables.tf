/************************************************** Fargate task configuration
 * ***********************************************/
variable "cpu" {
  description = <<EOS
The hard limit of CPU units to present for the task.
Power of 2 between 256 (.25 vCPU) and 4096 (4 vCPU)
EOS
}
variable "mem" {
  // https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
  description = <<EOS
The hard limit of memory (in MiB) to present to the task.
512, 1024, 2048                              for cpu = 256
1024, 2048, 3072, 4096                       for cpu = 512
Between 2048 and 8192 in increments of 1024  for cpu = 1024
Between 4096 and 16384 in increments of 1024 for cpu = 2048
Between 8192 and 30720 in increments of 1024 for cpu = 4096
EOS
}
variable "cpu_architecture" {
  type        = string
  description = "X86_64 or ARM64"
  default     = "X86_64"
}
variable "task_name" {
  type = string
}
variable "schedule" {
  type        = string
  description = "cron expression https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html#eb-cron-expressions"
}
variable "service_name" {
  type = string
}
variable "app_version" {
  type = string
}
variable "port" {
  default     = 0
  description = "The main port of the service. If using a loadbalancer the traffic will be sent to this port."
}
variable "ports" {
  default     = []
  description = "Every ports that need to be exposed by the service on its private IP address. Default to the value of the port variable if empty."
}
variable "image" {
  type = string
}
variable "platform_version" {
  default     = "LATEST"
  description = "https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html"
}
variable "task_role_policies_arn" {
  default = []
  type    = list(any)
}

variable "task_subnets" {
  type = list(string)
}
variable "ecs_cluster_arn" {
  type = string
}
variable "env_vars" {
  default   = {}
  type      = map(string)
  sensitive = true
}
variable "secrets_ssm_paths" {
  default = {}
  type    = map(string)
}
variable "command" {
  default = []
}
variable "side_car_image" {
  default = ""
}
variable "side_car_name" {
  default = ""
}

variable "tags" {
  default = {}
}
variable "docker_ulimits" {
  description = "see https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Ulimit.html"
  default     = []
}
variable "stop_timeout" {
  type        = number
  default     = 5
  description = "How long in seconds the orchestrator will wait to send a SIGKILL after a SIGTERM, max 120 seconds"
}

variable "enable_execute_command" {
  type        = bool
  default     = false
  description = "Allow an operator to exec inisde containers using aws ecs execute-command"
}

variable "docker_labels" {
  default     = {}
  type        = map(any)
  description = "Labels added to the main task container at runtime"
}

variable "container_healthcheck_command" {
  type        = list(any)
  default     = []
  description = "A string array representing the command that the container runs to determine if it is healthy. The string array must start with CMD to run the command arguments directly, or CMD-SHELL to run the command with the container's default shell."
}

variable "container_healthcheck_interval" {
  type        = number
  default     = 30
  description = "The time period in seconds between each health check execution. You may specify between 5 and 300 seconds."
}

variable "container_healthcheck_retries" {
  type        = number
  default     = 3
  description = "The number of times to retry a failed health check before the container is considered unhealthy. You may specify between 1 and 10 retries."
}

variable "container_healthcheck_timeout" {
  type        = number
  default     = 5
  description = "The time period in seconds to wait for a health check to succeed before it is considered a failure. You may specify between 2 and 60 seconds."
}
variable "container_healthcheck_start_period" {
  type        = number
  default     = 30
  description = "The optional grace period to provide containers time to bootstrap before failed health checks count towards the maximum number of retries. You can specify between 0 and 300 seconds."
}

/**************************************************
 * Datadog agent configuration
 * ***********************************************/
variable "datadog_agent_image_tag" {
  default = "812957082909.dkr.ecr.eu-central-1.amazonaws.com/public-ecr/datadog/agent:latest"
  type    = string
}
variable "datadog_agent_memory" {
  default     = 256
  type        = number
  description = "memory allocated to the Datadog agent container"
}
variable "collect_datadog_agent_logs" {
  default = false
  type    = bool
}
variable "enable_datadog_runtime_metrics" {
  default = false
  type    = bool
}
variable "enable_datadog_agent" {
  default     = false
  description = "To enable a side-car with datadog agent to collect Fargate tasks metrics"
}
variable "datadog_api_key" {
  default   = ""
  sensitive = true
}
variable "dd_tags" {
  default     = {}
  type        = map(string)
  description = "tags added to the DD_TAGS environment variable of the main task"
}
variable "datadog_mapper" {
  type        = string
  default     = ""
  description = "Where to put some inline mappings between metrics emitted by some software and Datadog. Used only for Airflow as of now."
}
# Metrics
variable "enable_datadog_dogstatsd_non_local_traffic" {
  type        = bool
  default     = false
  description = "To enable DogStatsD data collection in datadog agent"
}
# APM
variable "enable_datadog_agent_apm" {
  type        = bool
  default     = false
  description = "To enable APM data collection in datadog agent. See https://docs.datadoghq.com/integrations/ecs_fargate/?tab=fluentbitandfirelens#trace-collection"
}
variable "enable_datadog_non_local_apm" {
  type        = bool
  default     = false
  description = "To enable APM data collection in datadog agent with APM features."
}
variable "datadog_apm_ignore_ressources" {
  type        = list(string)
  default     = []
  description = "List of ressources (span names) to ignore in the APM. See https://docs.datadoghq.com/tracing/guide/ignoring_apm_resources/"
}
variable "enable_datadog_logs_injection" {
  type        = bool
  default     = false
  description = "To inject trace IDs, span IDs, env, service, and version in the logs. See https://docs.datadoghq.com/tracing/connect_logs_and_traces/"
}
variable "datadog_receiver_otlp_http_endpoint" {
  type        = string
  default     = "localhost:4318"
  description = "HTTP endpoint of the datadog agent used to receive traces in OpenTelemetry format"
}
# Source code integration
variable "enable_datadog_src_code_integration" {
  type        = bool
  default     = false
  description = "Enable the (APM) source code integration, commit_sha and repository_url should be defined as well"
}
variable "commit_sha" {
  type        = string
  default     = ""
  description = "git commit sha of the configured service version"
}
variable "repository_url" {
  type        = string
  default     = ""
  description = "http url of the git repository"
}
/**************************************************
 * Logging configuration
 * ***********************************************/
variable "logs_json" {
  type        = bool
  default     = false
  description = "Whether logs should be parsed as json. Works together with datadog logs."
}
variable "datadog_log_source" {
  default     = "default"
  description = "maps to the datadog ingestion parser"
}
variable "fluent_bit_image_tag" {
  type    = string
  default = "812957082909.dkr.ecr.eu-central-1.amazonaws.com/public-ecr/aws-observability/aws-for-fluent-bit:2.19.0"
}
