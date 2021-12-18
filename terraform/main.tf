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

data "aws_vpc" "default" {
  id = "vpc-0d7220f920a55a2de"
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}
