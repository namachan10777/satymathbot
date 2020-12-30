FROM ubuntu:20.10 AS builder

RUN apt-get update && \
	apt-get upgrade -y && \
	apt-get install -y wget make m4 gcc patch unzip git bzip2 pkg-config poppler-utils rsync

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

USER root
RUN cp /home/satymathbot/.opam/4.11.1/bin/satysfi /usr/local/bin/

# go install
RUN wget https://golang.org/dl/go1.15.6.linux-amd64.tar.gz -O go.tar.gz && \
	tar -C /usr/local -xzf go.tar.gz
ENV PATH $PATH:/usr/local/go/bin/

# build cmd
COPY . /satymathbot
WORKDIR /satymathbot/cmd/satymathbot
RUN go build && cp satymathbot /usr/local/bin

# minpack
RUN wget https://github.com/namachan10777/magicpak/releases/latest/download/magicpak-x86_64-unknown-linux-musl -O /usr/local/bin/magicpak && \
	chmod +x /usr/local/bin/magicpak && \
	/usr/local/bin/magicpak /usr/local/bin/satysfi /bundle_satysfi && \
	/usr/local/bin/magicpak /usr/bin/pdftoppm /bundle_pdftoppm && \
	/usr/local/bin/magicpak /usr/local/bin/satymathbot /bundle && \
	rsync -a /bundle_satysfi/ /bundle && \
	rsync -a /bundle_pdftoppm/ /bundle

RUN mkdir /bundle_home && \
	mkdir /bundle_home/.opam && \
	mkdir /bundle_home/.opam/4.11.1 && \
	mkdir /bundle_home/.opam/4.11.1/share && \
	mkdir /bundle/local/ && \
	mkdir /bundle/local/share

RUN cp -r /home/satymathbot/.satysfi /bundle/local/share/
RUN cp -r /home/satymathbot/.opam/4.11.1/share/satysfi /bundle_home/.opam/4.11.1/satysfi

FROM scratch
COPY --from=builder /bundle /
COPY --from=builder /bundle_home /home/satymathbot

ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
