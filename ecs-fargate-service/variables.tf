/**************************************************
 * Fargate task configuration
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
  type = string
  description = "X86_64 or ARM64"
  default = "X86_64"
}
variable "service_name" {}
// currently only used to set DD_VERSION
// TODO: make it mandatory once it is set everywhere
variable "app_version" {
  type    = string
  default = ""
}
variable "port" {
  default     = 0
  description = "The main port of the service. If using a loadbalancer the traffic will be sent to this port."
}
variable "ports" {
  default     = []
  description = "Every ports that need to be exposed by the service on its private IP address. Default to the value of the port variable if empty."
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
variable "healthcheck_grace_period" {
  default     = 30
  type        = number
  description = "Failed health check won't be accounted to determine the health status of the task during the grace period"
}
variable "waf_acl_arn" {
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
variable "task_public_ip" {
  type        = bool
  default     = false
  description = "Assign a public IP directly to the task, the task must be deployed on a public subnet"
}

variable "enable_execute_command" {
  type        = bool
  default     = false
  description = "Allow an operator to exec inisde containers using aws ecs execute-command"
}
variable "task_definition_only" {
  default     = false
  description = "When set to true only the task definition will be published"
}
variable "docker_labels" {
  default = {}
  type = map
  description = "Labels added to the main task container at runtime"
}
variable "force_new_deployment" {
  type        = bool
  default     = false
  description = "When enabled a new deployment of the service will be forced at each run (even without change)"
}
/**************************************************
 * Service discovery
 * ***********************************************/
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

/**************************************************
 * Autoscaling configuration
 * ***********************************************/
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
variable "autoscale_scale_in_cooldown" {
  default     = 300
  type        = number
  description = "Amount of time, in seconds, after a scale in activity completes before another scale in activity can start"
}
variable "autoscale_scale_out_cooldown" {
  default     = 300
  type        = number
  description = "Amount of time, in seconds, after a scale out activity completes before another scale out activity can start"
}

/**************************************************
 *  Load balancer configuration
 * ***********************************************/
variable "deregistration_delay" {
  type        = number
  description = "How long in second a load balancer will keep a target in DRAINING state before removing it from the targets. Most of the time this should be aligned with the idle timeout."
  default     = 60
}
variable "lb_algorithm_type" {
  default     = "round_robin"
  description = "Possible values 'round_robin' or 'least_outstanding_requests'. Applies to any type of LB (public or private)."
}
# Public load balancer
variable "enable_public_lb" {
  default     = true
  description = "Add a public loadbalancer in front of the service"
}
variable "lb_subnets" {
  description = "list of subnet IDs for the public LB"
}
variable "public_lb_access_logs_bucket" {
  description = "Where to put public LB access logs."
  default     = ""
}
variable "public_lb_dns_zone" {
  default     = ""
  description = "foo.bar."
}
variable "public_lb_dns_name" {
  default = ""
}
variable "public_lb_idle_timeout" {
  type        = number
  default     = 60
  description = "How long in seconds the load balancer will keep an idle connection open with the backend"
}
variable "lb_certificate_arn" {
  default = ""
}
# Private load balancer
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
  type        = number
  default     = 60
  description = "How long in seconds the load balancer will keep an idle connection open with the backend"
}
variable "lb_private_additional_security_groups" {
  description = "additional security groups for private LB"
  default     = []
}
# Healthcheck
variable "healthcheck_enabled" {
  type = bool
  default = true
}
variable "healthcheck_timeout" {
  default     = 2
  type        = number
  description = "Amount of time, in seconds, during which no response from a target means a failed health check. The range is 2–120 seconds"
}
variable "healthcheck_path" {
  default = ""
}
variable "healthcheck_port" {
  default = "traffic-port"
}
variable "healthcheck_interval" {
  description = "Approximate amount of time, in seconds, between health checks of an individual target. The range is 5-300. AWS default to 30. Must be greater than timeout."
  default = 5
}
variable "healthcheck_matcher" {
  default = "200-399"
}
variable "healthcheck_healthy_threshold" {
  description = "Number of consecutive health check successes required before considering a target healthy. The range is 2-10. Defaults to 3"
  default = 3
}
variable "healthcheck_unhealthy_threshold" {
  description = "Number of consecutive health check failures required before considering a target unhealthy. The range is 2-10. AWS defaults to 3"
  default = 5
}

/**************************************************
 * Logging configuration
 * ***********************************************/
variable "logs" {
  type        = string
  default     = "cloudwatch"
  description = "Should be \"cloudwatch\" or \"datadog\"."
}
variable "fluent_bit_image_tag" {
  type    = string
  default = "812957082909.dkr.ecr.eu-central-1.amazonaws.com/public-ecr/aws-observability/aws-for-fluent-bit:2.19.0"
}
variable "logs_json" {
  default     = false
  description = "Whether logs should be parsed as json. Works together with datadog logs."
}
variable "datadog_log_source" {
  default     = "default"
  description = "maps to the datadog ingestion parser"
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
  default     = ""
  description = "Where to put some inline mappings between metrics emitted by some software and Datadog. Used only for Airflow as of now."
}
# Metrics
variable "enable_datadog_dogstatsd_non_local_traffic" {
  default     = false
  description = "To enable DogStatsD data collection in datadog agent"
}
# APM
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
