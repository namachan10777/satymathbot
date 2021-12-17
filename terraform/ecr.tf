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
