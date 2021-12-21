data "aws_vpc" "main" {
  id = "vpc-0f2be0a648779a3d1"
}

locals {
  public_subnets = {
    a = "subnet-0115f2f8b56b46b63"
    c = "subnet-0846437d7294d2e43"
    d = "subnet-007856a76ecd11ec3"
  }

  private_subnets = {
    a = "subnet-0060810bbdafba96f"
    c = "subnet-0a825b3b3c269bc07"
    d = "subnet-0d67a9baaec6a1dbf"
  }
}

data "aws_subnet" "public" {
  for_each = local.public_subnets
  id       = each.value
}

data "aws_subnet" "private" {
  for_each = local.private_subnets
  id       = each.value
}