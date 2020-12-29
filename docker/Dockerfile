FROM ubuntu:20.10

FROM ubuntu:20.10

RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y wget make m4 gcc patch unzip git bzip2 pkg-config

RUN wget https://github.com/ocaml/opam/releases/download/2.0.7/opam-2.0.7-x86_64-linux -O /usr/local/bin/opam && \
	chmod +x /usr/local/bin/opam

RUN useradd satymathbot -m
USER satymathbot

RUN opam init --compiler=4.11.1 --disable-sandboxing
RUN eval $(opan env)
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git && \
	opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git && \
	opam update

RUN opam install -y opam-depext && \
	opam depext satysfi satysfi-dist satyrographos && \
	opam install -y satysfi satysfi-dist satyrographos

RUN opam install -y \
	satysfi-fonts-noto-sans satysfi-fonts-noto-sans-cjk-jp && \
	eval $(opam env) && \
	satyrographos install

RUN echo "eval $(opam env)" >> ~/.bashrc

WORKDIR "/home/satymathbot/satymathbot-reports"
ENTRYPOINT [ "/bin/bash" ]
