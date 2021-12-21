local core = import "./core.libsonnet";
local metrics = {
    prometheus: {
        build: "./docker-compose/metrics/prometheus"
    },
    grafana: {
        image: "grafana/grafana:8.3.3",
        ports: ["3000:3000"],
    },
};
core {
    services: core.services + metrics
}