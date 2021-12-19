local reivision = '8b54fe9930351baf44c14cc1831aa841a079a19c';
local image(component) = '966924987919.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-' + component + ':' + reivision;
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
