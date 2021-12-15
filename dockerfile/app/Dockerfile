FROM ocaml/opam:debian-10 as satysfi-builder
RUN opam switch create 4.10.0
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
RUN opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
RUN opam update
RUN opam install -y satysfi

FROM rust:slim-buster as satymathbot-builder
WORKDIR /work
COPY ./src /work/src
COPY ./templates /work/templates
COPY ./Cargo.toml /work/Cargo.toml
COPY ./Cargo.lock /work/Cargo.lock
RUN cargo build --release

FROM public.ecr.aws/debian/debian:buster
RUN apt-get update && apt-get install -y poppler-utils libjpeg-dev
COPY ./satysfi/empty.satyh /etc/satymathbot/empty.satyh
COPY --from=satysfi-builder /home/opam/.opam/4.10.0/bin/satysfi /usr/local/bin/satysfi
COPY --from=satymathbot-builder /work/target/release/satymathbot /usr/local/bin/satymathbot

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
CMD [ "-b", "/usr/local/bin/satysfi", "-s", "/etc/satymathbot/empty.satyh", "-p", "/usr/bin/pdftoppm" ]