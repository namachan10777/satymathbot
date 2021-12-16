FROM public.ecr.aws/debian/debian:buster as satysfi-builder
WORKDIR /work
ARG CURL_VERSION=7.80.0
RUN apt-get update && apt-get install -y wget make libtool libssl-dev autoconf patch unzip git bzip2 pkg-config
RUN wget https://github.com/curl/curl/releases/download/curl-$(echo ${CURL_VERSION} | tr . _)/curl-${CURL_VERSION}.tar.gz -O curl.tar.gz
RUN tar -xzf curl.tar.gz
WORKDIR /work/curl-${CURL_VERSION}
RUN autoreconf -fi
RUN ./configure --disable-shared --with-openssl
RUN make -j7
RUN make install
RUN wget https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh
RUN yes '' | sh install.sh
RUN useradd -rm -d /home/opam -s /bin/bash -u 1000 opam
USER opam
RUN opam init --compiler=4.10.0 -y --disable-sandboxing
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git
RUN opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git
RUN opam update
RUN opam install -y satysfi satysfi-dist satyrographos
RUN opam exec -- satyrographos install

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
RUN useradd -rm -d /home/satymathbot -s /bin/bash -u 1000 satymathbot
USER satymathbot
RUN mkdir /tmp/satymathbot
COPY --from=satysfi-builder /home/opam/.satysfi /home/satymathbot/.satysfi
COPY --from=satysfi-builder /home/opam /home/opam

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
CMD [ "-b", "/usr/local/bin/satysfi", "-s", "/etc/satymathbot/empty.satyh", "-p", "/usr/bin/pdftoppm", "-w", "/tmp/satymathbot" ]