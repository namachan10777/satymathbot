local core = import "./core-services.libsonnet";
local app_mock = {
    app: {
        build: "./docker-compose/app-mock"
    },
};
{
    version: "3.0",
    services: core + app_mock,
}