
module "test_private_lb" {
  source = "../ecs-fargate-service"

  service_name = "test-private-lb"
  image        = "jmalloc/echo-server"
  cpu          = 256
  mem          = 512
  port         = 8080

  ecs_cluster_id = data.terraform_remote_state.common.outputs.main_ecs_cluster_id
  vpc_id         = data.terraform_remote_state.common.outputs.common_vpc_id
  task_subnets   = data.terraform_remote_state.common.outputs.common_vpc_private_subnets

  additional_security_groups = [aws_security_group.test-sg.id]

  enable_public_lb = false

  # testing service with both private lb and local discovery enabled
  enable_local_discovery       = true
  discovery_namespace_id       = data.terraform_remote_state.common.outputs.service_discovery_namespace_id
  local_discovery_service_name = "test-private-lb"

  enable_private_lb   = true
  private_alb_arn     = data.terraform_remote_state.common.outputs.common_priv_alb_arn
  private_alb_sg_id   = data.terraform_remote_state.common.outputs.common_priv_alb_sg_id

  healthcheck_path    = "/"
  healthcheck_matcher = "200-499"
  private_lb_dns_zone = "${terraform.workspace}.priv."
  private_lb_dns_name = "test-private-lb"

  tags = {
    Environment = terraform.workspace
    Application = "foo"
  }
}

