local revision = 'e729a735e300bfafb63dc0f8d2fab3e5d4b78f4d';
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
local mountpoint = {
  containerPath: '/var/run/satymathbot',
  sourceVolume: 'sock',
};

local component(name) = {
  name: name,
  image: image(name),
  logConfiguration: logConfiguration,
  mountpoints: [mountpoint],
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
