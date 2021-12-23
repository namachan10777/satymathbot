local revision = '4bae0e549ff55a38a597a6d7e0866565e8523e28';
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
local mountPoint = {
  containerPath: '/var/run/satymathbot',
  sourceVolume: 'sock',
};

local component(name) = {
  name: name,
  image: image(name),
  logConfiguration: logConfiguration,
  mountPoints: [mountPoint],
};

local depends(name) = {
  containerName: name,
  condition: 'START',
};

[
  component('nginx') {
    dependsOn: [depends('app')],
  },
  component('prometheus'),
  component('promtail') {
    dependsOn: [depends('app')],
  },
  component('envoy') {
    portMappings: [
      {
        hostPort: 8080,
        containerPort: 8080,
      },
      {
        hostPort: 9901,
        containerPort: 9901,
      },
    ],
    dependsOn: [depends('nginx')],
  },
  component('app'),
]
