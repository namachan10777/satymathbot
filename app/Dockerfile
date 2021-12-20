FROM 966924987919.dkr.ecr.ap-northeast-1.amazonaws.com/satymathbot-satysfi:latest as satysfi-builder
FROM rust:slim-buster as satymathbot-builder
ENV PATH /root/.cargo/bin:$PATH
RUN cargo install cargo-chef
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
COPY --from=satysfi-builder /usr/local/bin/satysfi /usr/local/bin/satysfi
COPY --from=satymathbot-builder /work/target/release/satymathbot /usr/local/bin/satymathbot
RUN useradd -rm -d /home/satymathbot -s /bin/bash -u 1000 satymathbot
USER satymathbot
RUN mkdir /tmp/satymathbot
COPY --from=satysfi-builder /home/opam/.satysfi /home/satymathbot/.satysfi
COPY --from=satysfi-builder /home/opam /home/opam

EXPOSE 3000

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
CMD [ "-b", "/usr/local/bin/satysfi", "-s", "/etc/satymathbot/empty.satyh", "-p", "/usr/bin/pdftoppm", "-w", "/tmp/satymathbot" ]