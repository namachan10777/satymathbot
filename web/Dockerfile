FROM public.ecr.aws/docker/library/node:stretch-slim as builder
RUN npm i -g pnpm
WORKDIR /work
COPY package.json /work/
COPY pnpm-lock.yaml /work/
RUN pnpm i
COPY . /work
RUN pnpm build

FROM public.ecr.aws/docker/library/nginx:1.21.4


RUN groupadd -g 1000 satymathbot && useradd -rm -s /bin/bash -u 1000 -g satymathbot satymathbot
RUN touch /var/run/nginx.pid && \
    chown -R satymathbot:satymathbot /var/run/nginx.pid && \
    chown -R satymathbot:satymathbot /var/cache/nginx

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /work/build /web

USER satymathbot
