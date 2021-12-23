local revision = 'e36066b5a24c7113ceb715dcf63a36937df5c131';
local account_id = 966924987919;
local image(component) = account_id + '.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-' + component + ':' + revision;
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
  component('prometheus') {
    environment: [
      {
        name: 'AWS_ACCESS_KEY_ID',
        value: 'AKIA6CIJYNYHWKA6DW4P',
      },
    ],
    secrets: [
      {
        name: 'AWS_SECRET_ACCESS_KEY',
        valueFrom: 'arn:aws:ssm:ap-northeast-1:' + account_id + ':parameter/satymathbot/prometheus-writer/access-key',
      },
    ],
  },
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
