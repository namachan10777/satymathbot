FROM public.ecr.aws/docker/library/node:stretch-slim as builder
RUN npm i -g pnpm
WORKDIR /work
COPY . /work
RUN pnpm i
RUN pnpm build

FROM public.ecr.aws/docker/library/nginx:1.21.4

RUN touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid && \
    chown -R nginx:nginx /var/cache/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /work/build /web

USER root
RUN apt-get update && apt-get install -y fish

USER nginx
