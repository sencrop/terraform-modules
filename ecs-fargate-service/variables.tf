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
variable "service_name" {}
// currently only used to set DD_VERSION
// TODO: make it mandatory once it is set everywhere
variable "app_version" {
  type    = string
  default = ""
}
variable "port" {
  default = 0
}
variable "ports" {
  default = []
}
variable "image" {}
variable "vpc_id" {}
variable "platform_version" {
  default     = "LATEST"
  description = "https://docs.aws.amazon.com/AmazonECS/latest/developerguide/platform_versions.html"
}
variable "desired_tasks" {
  default = 1
}
variable "task_role_policies_arn" {
  default = []
  type    = list(any)
}
variable "lb_subnets" {
  description = "list of subnet IDs for the public LB"
}
variable "task_subnets" {}
variable "ecs_cluster_id" {}
variable "additional_security_groups" {
  description = "additional security groups for service"
  default     = []
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
variable "availability_sidecar_enable" {
  default = false
}
variable "availability_sidecar_image" {
  default = "812957082909.dkr.ecr.eu-central-1.amazonaws.com/observability-tools:8c06fd0"
}
variable "datadog_agent_image_tag" {
  default = "public.ecr.aws/datadog/agent:latest"
  type    = string
}
variable "collect_datadog_agent_logs" {
  default = false
  type    = bool
}

variable "healthcheck_path" {
  default = ""
}
variable "healthcheck_interval" {
  default = 30
}
variable "healthcheck_grace_period" {
  default = null
  type    = number
}
variable "healthcheck_timeout" {
  default = 5
}
variable "healthcheck_matcher" {
  default = "200-399"
}
variable "healthcheck_unhealthy_threshold" {
  default = 3
}
variable "lb_certificate_arn" {
  default = ""
}
variable "waf_acl_arn" {
  default = ""
}
variable "public_lb_dns_zone" {
  default     = ""
  description = "foo.bar."
}
variable "public_lb_dns_name" {
  default = ""
}
variable "public_lb_idle_timeout" {
  default = 60
}
variable "enable_public_lb" {
  default = true
}
variable "enable_local_discovery" {
  default = false
  # TODO validation: if true, it requires to declare other vars as well
}
variable "local_discovery_service_name" {
  default = ""
}
variable "discovery_namespace_id" {
  default = ""
}
variable "enable_autoscale" {
  default = false
}
variable "autoscale_max_tasks" {
  default = 4
}
variable "autoscale_min_tasks" {
  default = 1
}
variable "autoscale_cpu_target" {
  default = 80
}
variable "tags" {
  default = {}
}
variable "dd_tags" {
  default     = {}
  type        = map(string)
  description = "tags added to the DD_TAGS environment variable of the main task"
}

variable "deregistration_delay" {
  description = "load balancer target group deregistration"
  default     = 300
}
variable "docker_ulimits" {
  description = "see https://docs.aws.amazon.com/AmazonECS/latest/APIReference/API_Ulimit.html"
  default     = []
}
variable "logs" {
  type        = string
  default     = "cloudwatch"
  description = "Should be \"cloudwatch\" or \"datadog\"."
}
variable "datadog_api_key" {
  default   = ""
  sensitive = true
}
variable "logs_json" {
  default     = false
  description = "Whether logs should be parsed as json. Works together with datadog logs."
}
variable "datadog_log_source" {
  default     = "default"
  description = "maps to the datadog ingestion parser"
}
variable "enable_datadog_agent" {
  default     = false
  description = "To enable a side-car with datadog agent to collect Fargate tasks metrics"
}
variable "enable_datadog_agent_apm" {
  default     = false
  description = "To enable APM data collection in datadog agent. See https://docs.datadoghq.com/integrations/ecs_fargate/?tab=fluentbitandfirelens#trace-collection"
}
variable "enable_datadog_non_local_apm" {
  default     = false
  description = "To enable APM data collection in datadog agent with APM features."
}
variable "datadog_apm_ignore_ressources" {
  default     = []
  description = "List of ressources (span names) to ignore in the APM. See https://docs.datadoghq.com/tracing/guide/ignoring_apm_resources/"
}
variable "enable_datadog_logs_injection" {
  default     = false
  description = "To inject trace IDs, span IDs, env, service, and version in the logs. See https://docs.datadoghq.com/tracing/connect_logs_and_traces/"
}
variable "datadog_receiver_otlp_http_endpoint" {
  default     = "localhost:4318"
  description = "HTTP endpoint of the datadog agent used to receive traces in OpenTelemetry format"
}
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
variable "public_lb_access_logs_bucket" {
  description = "Where to put public LB access logs."
  default     = ""
}
variable "enable_private_lb" {
  default = false
}
variable "lb_private_subnets" {
  description = "list of subnet IDs for the private LB"
  default     = []
}
variable "private_lb_access_logs_bucket" {
  description = "Where to put private LB access logs."
  default     = ""
}
variable "private_lb_dns_zone" {
  default     = ""
  description = "foo.bar."
}
variable "private_lb_dns_name" {
  default = ""
}
variable "private_lb_idle_timeout" {
  default = 60
}
variable "lb_private_additional_security_groups" {
  description = "additional security groups for private LB"
  default     = []
}
variable "task_definition_only" {
  default = false
}
variable "datadog_mapper" {
  default     = ""
  description = "Where to put some inline mappings between metrics emitted by some software and Datadog. Used only for Airflow as of now."
}

variable "lb_algorithm_type" {
  default     = "round_robin"
  description = "Possible values 'round_robin' or 'least_outstanding_requests'. Applies to any type of LB (public or private)."
}
