provider "aws" {
  region = "ap-northeast-1"
}

terraform {
  required_version = ">= 1.0.9"
  backend "s3" {
    bucket  = "tfstate-namachan10777"
    region  = "ap-northeast-1"
    key     = "satymathbot.tfstate"
    encrypt = true
  }
}

data "aws_iam_policy_document" "codebuild-assume-role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "CodeBuildSatymathbot" {
  name               = "CodeBuildSatymathbot"
  assume_role_policy = data.aws_iam_policy_document.codebuild-assume-role.json
}

resource "aws_codebuild_project" "satymathbot" {
  name         = "satymathbot"
  service_role = aws_iam_role.CodeBuildSatymathbot.arn
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
    type         = "ARM_CONTAINER"
  }
  source {
    type      = "NO_SOURCE"
    buildspec = file("buildspec.yml")
  }
}

data "aws_iam_policy_document" "ecr-policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.CodeBuildSatymathbot.arn]
    }
    actions = [
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]
  }
}

locals {
  ecr-lifecycle-policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire images older than 14 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_repository" "satymathbot-app" {
  name = "satymathbot-app"
}

resource "aws_ecr_repository_policy" "satymathbot-app" {
  repository = aws_ecr_repository.satymathbot-app.name
  policy     = data.aws_iam_policy_document.ecr-policy.json
}

resource "aws_ecr_lifecycle_policy" "satymathbot-app" {
  repository = aws_ecr_repository.satymathbot-app.name
  policy     = local.ecr-lifecycle-policy
}

resource "aws_ecr_repository" "satymathbot-nginx" {
  name = "satymathbot-nginx"
}

resource "aws_ecr_repository_policy" "satymathbot-nginx" {
  repository = aws_ecr_repository.satymathbot-nginx.name
  policy     = data.aws_iam_policy_document.ecr-policy.json
}

resource "aws_ecr_lifecycle_policy" "satymathbot-nginx" {
  repository = aws_ecr_repository.satymathbot-nginx.name
  policy     = local.ecr-lifecycle-policy
}

resource "aws_ecr_repository" "satymathbot-envoy" {
  name = "satymathbot-envoy"
}

resource "aws_ecr_repository_policy" "satymathbot-envoy" {
  repository = aws_ecr_repository.satymathbot-envoy.name
  policy     = data.aws_iam_policy_document.ecr-policy.json
}

resource "aws_ecr_lifecycle_policy" "satymathbot-envoy" {
  repository = aws_ecr_repository.satymathbot-envoy.name
  policy     = local.ecr-lifecycle-policy
}
