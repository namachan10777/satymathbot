data "aws_vpc" "default" {
  id = "vpc-0d7220f920a55a2de"
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_acm_certificate" "main" {
  domain   = "satymathbot.science"
  statuses = ["ISSUED"]
}

resource "aws_security_group" "alb" {
  name        = "satymathbot-alb"
  description = "Allow https access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description      = "http from anywhere"
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

resource "aws_lb_target_group" "main" {
  name        = "satymathbot"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.default.id
  target_type = "ip"
  health_check {
    port = 80
    path = "/health"
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.main.arn

  default_action {
    target_group_arn = aws_lb_target_group.main.arn
    type             = "forward"
  }
}

resource "aws_security_group" "ecs" {
  name   = "satymathbot-ecs"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "satymathbot"
}

resource "aws_ecs_task_definition" "main" {
  family                   = "satymathbot"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  container_definitions    = file("definition.json")
}

resource "aws_ecs_service" "main" {
  name            = "satymathbot"
  cluster         = aws_ecs_cluster.main.name
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.main.arn
  network_configuration {
    subnets          = data.aws_subnet_ids.default.ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "nginx"
    container_port   = 80
  }
}