
module "test-names" {
  source = "../ecs-fargate-service"

  service_name = "test-names"
  image        = "jmalloc/echo-server"
  cpu          = 256
  mem          = 512
  port         = 8080

  ecs_cluster_id = data.terraform_remote_state.common.outputs.main_ecs_cluster_id
  vpc_id         = data.terraform_remote_state.common.outputs.common_vpc_id
  lb_subnets     = data.terraform_remote_state.common.outputs.common_vpc_public_subnets
  task_subnets   = data.terraform_remote_state.common.outputs.common_vpc_private_subnets

  additional_security_groups = [aws_security_group.test-sg.id]

  enable_public_lb    = true
  healthcheck_path    = "/"
  healthcheck_matcher = "200-499"
  lb_certificate_arn  = "arn:aws:acm:eu-central-1:812957082909:certificate/b6893e9c-6bc1-4d8b-b845-1604ef1a1704"
  public_lb_dns_zone  = "infra.sencrop.com."
  public_lb_dns_name  = "test-module"

  enable_local_discovery       = true
  discovery_namespace_id       = data.terraform_remote_state.common.outputs.service_discovery_namespace_id
  local_discovery_service_name = "test-names"

  tags = {
    Environment = local.testenv
    Application = "foo"
  }
}

