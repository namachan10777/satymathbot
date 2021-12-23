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
      build: './web',
      volumes: [
        'sock:/var/run/satymathbot'
      ],
    },
    envoy: {
      build: './envoy',
      ports: ['8080:8080', '9901:9901', '8081:8081'],
      volumes: [
        'sock:/var/run/satymathbot'
      ],
    },
  },
  volumes: {
    sock: {},
  },
}
