local revision = 'a02afa40aa78d41f5ff39a7496da99e503ee8868';
local image(component) = '966924987919.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-' + component + ':' + revision;
local logConfiguration = {
  logDriver: 'awslogs',
  options: {
    'awslogs-group': 'satymathbot',
    'awslogs-region': 'ap-northeast-1',
    'awslogs-create-group': 'true',
    'awslogs-stream-prefix': 'satymathbot',
  },
};

local component(name) = {
  name: name,
  image: image(name),
  logConfiguration: logConfiguration,
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
