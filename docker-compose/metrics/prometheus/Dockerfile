FROM prom/prometheus:v2.48.1

COPY ./files/etc/prometheus /etc/prometheus

CMD ["--config.file", "/etc/prometheus/prometheus.yml"]