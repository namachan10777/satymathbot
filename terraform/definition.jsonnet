[
  {
    name: 'nginx',
    image: 'nginx:latest',
    portMappings: [
      {
        containerPort: 80,
        hostPort: 80,
      },
    ],
    logConfiguration: {
        logDriver: 'awslogs',
        options: {
            "awslogs-group": "satymathbot-nginx",
            "awslogs-region": "ap-northeast-1",
            "awslogs-create-group": "true",
            "awslogs-stream-prefix": "satymathbot-nginx"
        }
    }
  },
]
