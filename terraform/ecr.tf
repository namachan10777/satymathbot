data "aws_iam_policy_document" "ecr-policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.CodeBuildSatymathbot.arn, aws_iam_role.github-actions.arn]
    }
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
  repositories = toset(["app", "web", "envoy", "promtail", "prometheus"])
}

resource "aws_ecr_repository" "satymathbot" {
  for_each = local.repositories
  name     = "satymathbot-${each.value}"
}

resource "aws_ecr_repository_policy" "satymathbot" {
  for_each   = local.repositories
  repository = aws_ecr_repository.satymathbot[each.value].name
  policy     = data.aws_iam_policy_document.ecr-policy.json
}

resource "aws_ecr_lifecycle_policy" "satymathbot" {
  for_each   = local.repositories
  repository = aws_ecr_repository.satymathbot[each.value].name
  policy     = local.ecr-lifecycle-policy
}
