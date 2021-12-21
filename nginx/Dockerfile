FROM public.ecr.aws/docker/library/nginx:1.21.4

COPY ./files/etc/nginx/nginx.conf /etc/nginx/nginx.conf

RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx

VOLUME [ "/var/run/satymathbot" ]

USER nginx
