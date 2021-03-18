
module "test_access_logs" {
  source = "../ecs-fargate-service"

  service_name = "test-access-logs"
  image        = "jmalloc/echo-server"
  cpu          = 256
  mem          = 512
  port         = 8080

  ecs_cluster_id = data.terraform_remote_state.common.outputs.main_ecs_cluster_id
  vpc_id         = data.terraform_remote_state.common.outputs.common_vpc_id
  lb_subnets     = data.terraform_remote_state.common.outputs.common_vpc_public_subnets
  task_subnets   = data.terraform_remote_state.common.outputs.common_vpc_private_subnets

  additional_security_groups = [aws_security_group.test-sg.id]

  enable_public_lb       = true
  lb_certificate_arn  = "arn:aws:acm:eu-central-1:812957082909:certificate/b6893e9c-6bc1-4d8b-b845-1604ef1a1704"
  waf_acl_arn = data.terraform_remote_state.common.outputs.general_acl_arn
  public_lb_dns_zone  = "infra.sencrop.com."
  public_lb_dns_name  = "test-access-logs"
  public_lb_access_logs_bucket = data.terraform_remote_state.common.outputs.access_logs_s3_bucket

  enable_local_discovery = false

  tags = {
    Environment = local.testenv
    Application = "foo"
  }

  logs            = "datadog"
  datadog_api_key = data.aws_ssm_parameter.datadog_api_key.value
}

