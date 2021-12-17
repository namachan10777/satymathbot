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
