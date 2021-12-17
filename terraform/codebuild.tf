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

data "aws_iam_policy_document" "codebuild" {
  statement {
    resources = [
      "*"
    ]
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:GetLogEvents",
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "CodeBuildSatymathbot"
  policy = data.aws_iam_policy_document.codebuild.json
  role   = aws_iam_role.CodeBuildSatymathbot.name
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

module "oidc-provider-data" {
  source     = "reegnz/oidc-provider-data/aws"
  version    = "0.0.3"
  issuer_url = "https://token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github-actions-assume-role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = ["${module.oidc-provider-data.arn}"]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:namachan10777/satymathbot:*"]
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "self" {}


data "aws_iam_policy_document" "github-actions" {
  statement {
    effect = "Allow"
    actions = [
      "codebuild:StartBuild",
      "codebuild:BatchGetBuilds",
      "logs:GetLogEvents"
    ]
    resources = [aws_codebuild_project.satymathbot.arn]
  }
}

resource "aws_iam_role" "github-actions" {
  name               = "SatymathBotGitHubActions"
  assume_role_policy = data.aws_iam_policy_document.github-actions-assume-role.json
}

resource "aws_iam_role_policy" "github-actions" {
  name   = "SatymathBotGitHubActions"
  role   = aws_iam_role.github-actions.name
  policy = data.aws_iam_policy_document.github-actions.json
}