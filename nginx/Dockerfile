FROM public.ecr.aws/docker/library/nginx:latest:1.21.4

COPY ./files/etc/nginx/nginx.conf /etc/nginx/nginx.conf

RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx

USER nginx
