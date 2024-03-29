
module "test_datadog_json" {
  source = "../ecs-fargate-service"

  service_name = "test-datadog-json"
  image        = "jmalloc/echo-server"
  cpu          = 256
  mem          = 512
  port         = 8080

  ecs_cluster_id = data.terraform_remote_state.common.outputs.main_ecs_cluster_id
  vpc_id         = data.terraform_remote_state.common.outputs.common_vpc_id
  lb_subnets     = data.terraform_remote_state.common.outputs.common_vpc_public_subnets
  task_subnets   = data.terraform_remote_state.common.outputs.common_vpc_private_subnets

  additional_security_groups = [aws_security_group.test-sg.id]

  enable_public_lb       = false
  enable_local_discovery = false

  tags = {
    Environment = terraform.workspace
    Application = "foo"
  }

  logs            = "datadog"
  logs_json       = true
  datadog_api_key = data.aws_ssm_parameter.datadog_api_key.value
}

