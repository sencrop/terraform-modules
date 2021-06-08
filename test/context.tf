provider "aws" {
  region = "eu-central-1"
}

terraform {
  required_version = "= 0.14.11"
}

locals {
  testenv = "test"
}


data "terraform_remote_state" "common" {
  backend = "s3"

  config = {
    bucket = "sencrop-terraform-state"
    key    = "env:/${local.testenv}/common.tfstate"
    region = "eu-central-1"
  }
}

resource "aws_security_group" "test-sg" {
  name_prefix = "test-sg"
  description = "test"
  vpc_id      = data.terraform_remote_state.common.outputs.common_vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = local.testenv
  }
}

data "aws_ssm_parameter" "datadog_api_key" {
  name = "/tf/${local.testenv}/datadog/api_key"
}
