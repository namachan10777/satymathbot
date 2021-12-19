{
  app: {
    build: './app',
  },
  nginx: {
    build: './nginx',
  },
  envoy: {
    build: './envoy',
    ports: ['8080:8080', '9901:9901'],
  },
}
