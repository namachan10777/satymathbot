FROM 966924987919.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-satysfi:latest as satysfi-builder
FROM public.ecr.aws/docker/library/rust:latest as satymathbot-builder
WORKDIR /work
COPY Cargo.lock /work/Cargo.lock
COPY Cargo.toml /work/Cargo.toml
RUN echo 'fn main(){}' > /work/dummy.rs
RUN sed -ie 's#src/main.rs#dummy.rs#g' Cargo.toml
RUN cargo build --release
COPY src /work/src
COPY templates /work/templates
RUN sed -ie 's#dummy.rs#src/main.rs#g' Cargo.toml
RUN cargo build --release

FROM public.ecr.aws/ubuntu/ubuntu:21.04
RUN apt-get update && apt-get install -y poppler-utils libjpeg-dev
COPY ./satysfi/empty.satyh /etc/satymathbot/empty.satyh
COPY ./prod.ron /etc/satymathbot/config.ron
COPY --from=satysfi-builder /usr/local/bin/satysfi /usr/local/bin/satysfi
COPY --from=satymathbot-builder /work/target/release/satymathbot /usr/local/bin/satymathbot
COPY --from=satysfi-builder /home/opam/.satysfi /home/satymathbot/.satysfi
COPY --from=satysfi-builder /home/opam/.opam/4.10/share/satysfi /home/opam/.opam/4.10/share/satysfi

RUN groupadd -g 101 satymathbot
RUN useradd -rm -s /bin/bash -u 101 -g satymathbot satymathbot
RUN mkdir /var/run/satymathbot
RUN chown satymathbot:satymathbot /var/run/satymathbot
RUN chmod 700 /var/run/satymathbot
USER satymathbot

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
CMD [ "-s", "/etc/satymathbot/config.ron" ]
