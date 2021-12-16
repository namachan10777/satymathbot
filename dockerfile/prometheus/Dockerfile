FROM prom/prometheus:v2.32.0

COPY ./files/etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml

CMD ["--config.file", "/etc/prometheus/prometheus.yml"]