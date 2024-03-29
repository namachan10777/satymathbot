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
      "arn:aws:logs:ap-northeast-1:966924987919:log-group:*"
    ]
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
    ]
  }
  statement {
    effect    = "Allow"
    resources = ["*"]
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
  }
  statement {
    resources = [
      "arn:aws:logs:ap-northeast-1:966924987919:log-group:/aws/codebuild/satymathbot:*"
    ]
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }

  statement {
    resources = [
      "*"
    ]
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
  }
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "CodeBuildSatymathbot"
  policy = data.aws_iam_policy_document.codebuild.json
  role   = aws_iam_role.CodeBuildSatymathbot.name
}

resource "aws_codebuild_project" "satymathbot" {
  name          = "satymathbot"
  service_role  = aws_iam_role.CodeBuildSatymathbot.arn
  build_timeout = 60
  artifacts {
    type = "NO_ARTIFACTS"
  }
  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:2.0"
    type            = "ARM_CONTAINER"
    privileged_mode = true
  }
  source {
    type      = "NO_SOURCE"
    buildspec = file("buildspec.yml")
  }
}

resource "aws_iam_openid_connect_provider" "github-actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github-actions-assume-role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github-actions.arn]
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
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    resources = ["arn:aws:logs:ap-northeast-1:966924987919:log-group:/aws/codebuild/satymathbot:*"]
    effect    = "Allow"
    actions = [
      "logs:GetLogEvents",
    ]
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
