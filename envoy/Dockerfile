FROM envoyproxy/envoy:v1.20.1

COPY files/etc/envoy /etc/envoy

EXPOSE 8080
EXPOSE 9901

CMD ["-c", "/etc/envoy/envoy.yml"]