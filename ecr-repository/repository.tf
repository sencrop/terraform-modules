resource "aws_ecr_repository" "repository" {
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    "terraform.managed" = "true"
  }
}

resource "aws_ecr_lifecycle_policy" "common_policy" {
  repository = aws_ecr_repository.repository.name
  policy     = file("${path.module}/common_policy.json")
}

