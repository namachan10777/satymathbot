resource "aws_security_group" "ecs" {
  name   = "satymathbot-ecs"
  vpc_id = data.aws_vpc.main.id
  ingress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = [for subnet in data.aws_subnet.public : subnet.cidr_block]
    ipv6_cidr_blocks = [for subnet in data.aws_subnet.public : subnet.ipv6_cidr_block]
  }
  ingress {
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = [for subnet in data.aws_subnet.public : subnet.cidr_block]
    ipv6_cidr_blocks = [for subnet in data.aws_subnet.public : subnet.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_ecs_cluster" "main" {
  name = "satymathbot"
}

data "aws_iam_policy_document" "ecs-execution-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-execution" {
  name               = "EcsTaskExecution"
  assume_role_policy = data.aws_iam_policy_document.ecs-execution-assume-role.json
}

data "aws_iam_policy" "amazon-ecs-task-execution-role-policy" {
  name = "AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs-execution-default" {
  role       = aws_iam_role.ecs-execution.id
  policy_arn = data.aws_iam_policy.amazon-ecs-task-execution-role-policy.arn
}

data "aws_iam_policy_document" "ecs-task-execution" {
  statement {
    actions = [
      "logs:CreateLogGroup",
    ]
    resources = ["arn:aws:logs:ap-northeast-1:966924987919:log-group:*"]
  }
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["arn:aws:logs:ap-northeast-1:966924987919:log-group:satymathbot:*"]
  }
  statement {
    actions = [
      "ssm:GetParameters",
    ]
    resources = [
      aws_ssm_parameter.prometheus-writer.arn,
    ]
  }
}
resource "aws_iam_role_policy" "ecs-execution-awslogs" {
  name   = "EcsTaskExecutionAwslogs"
  role   = aws_iam_role.ecs-execution.id
  policy = data.aws_iam_policy_document.ecs-task-execution.json
}

resource "aws_ecs_task_definition" "main" {
  family                   = "satymathbot"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  container_definitions    = file("definition.json")
  execution_role_arn       = aws_iam_role.ecs-execution.arn
  task_role_arn            = aws_iam_role.ecs.arn
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }
  volume {
    name = "sock"
  }
}

data "aws_iam_policy_document" "ecs-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "ecs" {
  name               = "SatymathbotEcs"
  assume_role_policy = data.aws_iam_policy_document.ecs-assume-role.json
}

resource "aws_iam_user" "prometheus-writer" {
  name = "SatymathbotPrometheusWriter"
  path = "/prometheus/"
}

resource "aws_iam_access_key" "prometheus-writer" {
  user = aws_iam_user.prometheus-writer.name
}

output "prometheus-writer-access-key-id" {
  value = aws_iam_access_key.prometheus-writer.id
}

resource "aws_iam_policy_attachment" "prometheus-writer" {
  name       = "SatymathbotPrometheusWrite"
  users      = [aws_iam_user.prometheus-writer.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}

resource "aws_ssm_parameter" "prometheus-writer" {
  name  = "/satymathbot/prometheus-writer/access-key"
  type  = "String"
  value = aws_iam_access_key.prometheus-writer.secret
}

resource "aws_ecs_service" "main" {
  name            = "satymathbot"
  cluster         = aws_ecs_cluster.main.name
  launch_type     = "FARGATE"
  desired_count   = 1
  task_definition = aws_ecs_task_definition.main.arn
  depends_on      = [aws_alb.main]
  network_configuration {
    subnets          = [for subnet in data.aws_subnet.public : subnet.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "envoy"
    container_port   = 8080
  }
}
