FROM envoyproxy/envoy:v1.21.0

COPY files/etc/envoy /etc/envoy

ENV ENVOY_UID=101
ENV ENVOY_GID=101

EXPOSE 8080
EXPOSE 9901

CMD ["-c", "/etc/envoy/envoy.yml"]
