FROM prom/prometheus:v2.47.0

COPY ./files/etc/prometheus /etc/prometheus

CMD ["--config.file", "/etc/prometheus/prometheus.yml"]