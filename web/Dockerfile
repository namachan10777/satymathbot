FROM public.ecr.aws/docker/library/node:stretch-slim as builder

RUN npm i -g pnpm
WORKDIR /work
COPY . /work
RUN pnpm i
RUN pnpm build

FROM public.ecr.aws/docker/library/node:stretch-slim
COPY --from=builder /work/build /web/build
COPY --from=builder /work/node_modules /web/node_modules
COPY --from=builder /work/package.json /web/package.json
COPY forcefulshutdown.mjs /work/forcefulshutdown.mjs
RUN cat /work/forcefulshutdown.mjs >> /web/build/index.js
CMD [ "/web/build/index.js" ]
