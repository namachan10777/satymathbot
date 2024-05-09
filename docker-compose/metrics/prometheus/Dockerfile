FROM prom/prometheus:v2.52.0

COPY ./files/etc/prometheus /etc/prometheus

CMD ["--config.file", "/etc/prometheus/prometheus.yml"]