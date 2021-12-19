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
