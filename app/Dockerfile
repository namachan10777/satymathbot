FROM ocaml/opam:ubuntu-22.10-ocaml-4.10 as satysfi-builder
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
RUN opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
RUN opam update

USER root
RUN apt-get update && apt-get install -y pkg-config

USER opam
RUN opam install -y \
    satysfi satysfi-dist satyrographos \
    satysfi-siunitx satysfi-uline satysfi-matrix
RUN opam exec -- satyrographos install

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

FROM public.ecr.aws/ubuntu/ubuntu:22.10
RUN apt-get update && apt-get install -y poppler-utils libjpeg-dev sudo
COPY ./satysfi/empty.satyh /etc/satymathbot/empty.satyh
COPY ./prod.ron /etc/satymathbot/config.ron
COPY --from=satymathbot-builder /work/target/release/satymathbot /usr/local/bin/satymathbot
COPY --from=satysfi-builder /home/opam/.opam/4.10/share/satysfi /home/opam/.opam/4.10/share/satysfi
COPY --from=satysfi-builder /home/opam/.opam/4.10/bin/satysfi /usr/local/bin/satysfi
COPY ./entry.sh /usr/local/bin/entry.sh

RUN groupadd -g 1000 satymathbot && useradd -rm -s /bin/bash -u 1000 -g satymathbot satymathbot

COPY --from=satysfi-builder /home/opam/.satysfi/ /home/satymathbot/.satysfi

RUN chown root:root /usr/local/bin/entry.sh && chmod 4755 /usr/local/bin/entry.sh
RUN chown satymathbot:satymathbot /usr/local/bin/satymathbot && chmod 4755 /usr/local/bin/satymathbot

VOLUME [ "/var/run/satymathbot" ]

ENTRYPOINT [ "/usr/local/bin/entry.sh" ]
CMD [ "-s", "/etc/satymathbot/config.ron" ]
