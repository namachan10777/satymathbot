FROM ubuntu:20.10 AS builder

RUN apt-get update && \
	apt-get install --no-install-recommends -y \
	pkg-config=0.29.2-1ubuntu1 \
	poppler-utils=20.09.0-2ubuntu2 \
	make=4.3-4ubuntu1 \
	m4=1.4.18-4 \
	gcc=4:10.2.0-1ubuntu1 \
	libc6-dev=2.32-0ubuntu3 \
	patch=2.7.6-6 \
	unzip=6.0-25ubuntu1 \
	git=1:2.27.0-1ubuntu1 \
	bzip2=1.0.8-4ubuntu2 \
	wget=1.20.3-1ubuntu1 \
	rsync=3.2.3-2ubuntu1 \
	ca-certificates=20201027ubuntu0.20.10.1

RUN wget https://github.com/ocaml/opam/releases/download/2.0.7/opam-2.0.7-x86_64-linux -O /usr/local/bin/opam && \
	chmod +x /usr/local/bin/opam

RUN useradd satymathbot -m
USER satymathbot

RUN opam init --compiler=4.11.1 --disable-sandboxing
RUN eval "$(opan env)"
RUN opam repository add satysfi-external https://github.com/gfngfn/satysfi-external-repo.git && \
	opam repository add satyrographos https://github.com/na4zagin3/satyrographos-repo.git && \
	opam update


RUN opam install -y opam-depext && \
	opam depext satysfi satysfi-dist satyrographos && \
	opam install -y satysfi satysfi-dist satyrographos

RUN opam install -y \
	satysfi-fonts-noto-sans satysfi-fonts-noto-sans-cjk-jp && \
	eval "$(opam env)" && \
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

USER satymathbot

# minpack
RUN wget https://github.com/namachan10777/magicpak/releases/latest/download/magicpak-x86_64-unknown-linux-musl -O "$HOME/magicpak" && \
	chmod +x "$HOME/magicpak" && \
	"$HOME/magicpak" /usr/local/bin/satysfi "$HOME/bundle_satysfi" && \
	"$HOME/magicpak" /usr/bin/pdftoppm "$HOME/bundle_pdftoppm" && \
	"$HOME/magicpak" /usr/local/bin/satymathbot "$HOME/bundle" && \
	rsync -a "$HOME/bundle_satysfi/" "$HOME/bundle" && \
	rsync -a "$HOME/bundle_pdftoppm/" "$HOME/bundle"

RUN mkdir -p "$HOME/bundle/home/satymathbot/.opam/4.11.1/share" && \
	mkdir -p "$HOME/bundle/usr/local/share"

RUN cp -r /home/satymathbot/.satysfi "$HOME/bundle/usr/local/share/satysfi"
RUN cp -r /home/satymathbot/.opam/4.11.1/share/satysfi "$HOME/bundle/home/satymathbot/.opam/4.11.1/share/satysfi"

FROM scratch
COPY --from=builder /home/satymathbot/bundle /
COPY satysfi/empty.satyh /usr/local/share/satysfi/dist/packages/


EXPOSE 8080
ENTRYPOINT [ "/usr/local/bin/satymathbot" ]
