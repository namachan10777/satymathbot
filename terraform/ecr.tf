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

locals {
  repositories = toset(["app", "nginx", "envoy"])
}

resource "aws_ecr_repository" "satymathbot-app" {
  for_each = local.repositories
  name     = "satymathbot-${each.value}"
}

resource "aws_ecr_repository_policy" "satymathbot-app" {
  for_each   = local.repositories
  repository = "satymathbot-${each.value}"
  policy     = data.aws_iam_policy_document.ecr-policy.json
}

resource "aws_ecr_lifecycle_policy" "satymathbot-app" {
  for_each   = local.repositories
  repository = "satymathbot-${each.value}"
  policy     = local.ecr-lifecycle-policy
}
