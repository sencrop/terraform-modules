
module "test_private_lb" {
  source = "../ecs-fargate-service"

  service_name = "test-private-lb"
  image        = "jmalloc/echo-server"
  cpu          = 256
  mem          = 512
  port         = 8080

  ecs_cluster_id = data.terraform_remote_state.common.outputs.main_ecs_cluster_id
  vpc_id         = data.terraform_remote_state.common.outputs.common_vpc_id
  lb_subnets     = data.terraform_remote_state.common.outputs.common_vpc_public_subnets
  task_subnets   = data.terraform_remote_state.common.outputs.common_vpc_private_subnets

  additional_security_groups = [aws_security_group.test-sg.id]

  enable_public_lb = false
  enable_local_discovery = false

  enable_private_lb   = true
  lb_private_subnets  = data.terraform_remote_state.common.outputs.common_vpc_private_subnets
  healthcheck_path    = "/"
  healthcheck_matcher = "200-499"
  private_lb_dns_zone  = "${terraform.workspace}.priv."
  private_lb_dns_name  = "test-private-lb"

  tags = {
    Environment = local.testenv
    Application = "foo"
  }
}

