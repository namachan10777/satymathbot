data "aws_vpc" "default" {
  id = "vpc-0d7220f920a55a2de"
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "alb" {
  name        = "satymathbot-alb"
  description = "Allow https access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "TLS from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_alb" "main" {
  name               = "satymathbot"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = data.aws_subnet_ids.default.ids

  enable_deletion_protection = true
}