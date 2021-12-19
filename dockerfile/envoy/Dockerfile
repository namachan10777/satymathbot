FROM envoyproxy/envoy:v1.20.1

COPY files/etc/envoy /etc/envoy

EXPOSE 80

CMD ["-c", "/etc/envoy/envoy.yml"]