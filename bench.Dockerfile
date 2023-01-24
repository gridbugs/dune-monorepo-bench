FROM ocaml/opam:debian-10-ocaml-4.12

RUN echo hi

RUN ls

RUN pwd

RUN apt-get update
