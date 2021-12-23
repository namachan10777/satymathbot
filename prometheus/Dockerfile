FROM quay.io/prometheus/prometheus:v2.32.1

COPY prometheus.yml /etc/prometheus/prometheus.yml

CMD ["--enable-feature=agent", "--config.file=/etc/prometheus/prometheus.yml"]
