resource "aws_security_group" "alb" {
  name        = "satymathbot-alb"
  description = "Allow https access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "http from anywhere"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_alb" "main" {
  name               = "satymathbot"
  depends_on         = [aws_route_table_association.public]
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]
  ip_address_type    = "dualstack"

  enable_deletion_protection = true
}

resource "aws_lb_target_group" "main" {
  name        = "satymathbot"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    port     = 80
    path     = "/"
    timeout  = 10
    interval = 30
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_alb.main.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    target_group_arn = aws_lb_target_group.main.arn
    type             = "forward"
  }
}
