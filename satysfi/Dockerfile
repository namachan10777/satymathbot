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

USER root
RUN cp /home/opam/.opam/4.10.0/bin/satysfi /usr/local/bin/satysfi

USER satysfi

ENTRYPOINT [ "/usr/local/bin/satysfi" ]