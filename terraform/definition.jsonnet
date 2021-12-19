local revision = '91996d5f6c777d6bda7e7bde918ac0a88d38f27a';
local image(component) = '966924987919.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-' + component + ':' + revision;
local logConfiguration(component) = {
  logDriver: 'awslogs',
  options: {
    'awslogs-group': 'satymathbot',
    'awslogs-region': 'ap-northeast-1',
    'awslogs-create-group': 'true',
    'awslogs-stream-prefix': 'satymathbot' + component,
  },
};

local component(name) = {
  name: name,
  image: image(name),
  logConfiguration: logConfiguration(name),
};

[
  component('nginx'),
  component('envoy') {
    portMappings: [{
      hostPort: 8080,
      containerPort: 8080,
    }],
  },
  component('app'),
]
