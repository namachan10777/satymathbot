FROM ocaml/opam:ubuntu-21.04-ocaml-4.10 as satysfi-builder
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
RUN opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
RUN opam update

USER root
RUN apt-get update && apt-get install -y pkg-config

USER opam
RUN opam install -y satysfi satysfi-dist satyrographos
RUN opam exec -- satyrographos install

USER root
RUN cp /home/opam/.opam/4.10/bin/satysfi /usr/local/bin/satysfi

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
USER satymathbot

VOLUME [ "/var/run/satymathbot" ]

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
CMD [ "-s", "/etc/satymathbot/config.ron" ]
