resource "aws_security_group" "ecs" {
  name   = "satymathbot-ecs"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

data "aws_iam_policy_document" "ecs-task-execution-awslogs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "ecs-execution-awslogs" {
  name   = "EcsTaskExecutionAwslogs"
  role   = aws_iam_role.ecs-execution.id
  policy = data.aws_iam_policy_document.ecs-task-execution-awslogs.json
}

resource "aws_ecs_task_definition" "main" {
  family                   = "satymathbot"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  network_mode             = "awsvpc"
  container_definitions    = file("definition.json")
  execution_role_arn       = aws_iam_role.ecs-execution.arn
}

data "aws_iam_policy_document" "ecs-assume-role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "ecs" {
  name               = "satymathbot-ecs"
  assume_role_policy = data.aws_iam_policy_document.ecs-assume-role.json
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
