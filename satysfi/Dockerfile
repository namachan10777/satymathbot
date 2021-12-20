FROM ocaml/opam:ubuntu-21.04-ocaml-4.10
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

USER satysfi

ENTRYPOINT [ "/usr/local/bin/satysfi" ]
