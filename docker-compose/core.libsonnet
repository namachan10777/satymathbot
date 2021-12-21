{
  version: "3.0",
  services: {
    app: {
      build: './app',
      volumes: [
        'sock:/var/run/satymathbot'
      ],
    },
    nginx: {
      build: './nginx',
      volumes: [
        'sock:/var/run/satymathbot'
      ],
    },
    envoy: {
      build: './envoy',
      ports: ['8080:8080', '9901:9901'],
      volumes: [
        'sock:/var/run/satymathbot'
      ],
    },
  },
  volumes: {
    sock: {},
  },
}
