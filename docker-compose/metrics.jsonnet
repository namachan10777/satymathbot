local core = import "./core-services.libsonnet";
local metrics = {
    prometheus: {
        build: "./docker-compose/metrics/prometheus"
    },
    grafana: {
        image: "grafana/grafana:8.3.3",
        ports: ["3000:3000"],
    },
};
{
    version: "3.0",
    services: core + metrics,
}