local core = import "./core.libsonnet";
local app_mock = {
    app: {
        build: "./docker-compose/app-mock"
    },
};
core {
    services: core.services + app_mock
}