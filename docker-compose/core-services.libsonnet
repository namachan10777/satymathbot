{
    app: {
        build: {
            context: ".",
            dockerfile: "./dockerfile/app/Dockerfile",
        },
    },
    nginx: {
        build: {
            context: "./dockerfile/nginx",
            dockerfile: "Dockerfile",
        },
    },
    envoy: {
        build: {
            context: "./dockerfile/envoy",
            dockerfile: "Dockerfile",
        },
        ports: ["8080:8080","9901:9901"],
    },
}