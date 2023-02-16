FROM debian

# Enable non-free packages
RUN sed -i '/^deb/ s/$/ non-free/' /etc/apt/sources.list

# Install tools and system dependencies of packages
RUN apt-get update -y && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  build-essential \
  pkg-config \
  opam \
  neovim \
  sudo \
  autoconf \
  zlib1g-dev \
  libcairo2-dev \
  libcurl4-gnutls-dev \
  libsnmp-dev \
  libgmp-dev \
  libbluetooth-dev \
  cmake \
  libfarmhash-dev \
  libgl-dev \
  libnlopt-dev \
  libmpfr-dev \
  r-base-core \
  libjemalloc-dev \
  libsnappy-dev \
  libpapi-dev \
  libgles2 \
  libgles2-mesa-dev \
  fswatch \
  librdkafka-dev \
  google-perftools \
  libgoogle-perftools-dev \
  libglew-dev \
  wget \
  guile-3.0-dev \
  portaudio19-dev \
  libglpk-dev \
  libportmidi-dev \
  libmpg123-dev \
  libgtksourceview-3.0-dev \
  libhidapi-dev \
  libfftw3-dev \
  libasound2-dev \
  libzmq3-dev \
  r-base-dev \
  libgtk2.0-dev \
  libsoundtouch-dev \
  libmp3lame-dev \
  libplplot-dev \
  libogg-dev \
  libavutil-dev \
  libavfilter-dev \
  libswresample-dev \
  libavcodec-dev \
  libfdk-aac-dev \
  libfaad2 \
  libsamplerate0-dev \
  libao-dev \
  liblmdb-dev \
  libnl-3-dev \
  libnl-route-3-dev \
  sqlite3 \
  libsqlite3-dev \
  cargo \
  libtool \
  libopenimageio-dev \
  libtidy-dev \
  libleveldb-dev \
  libgtkspell-dev \
  libtag1-dev \
  libsrt-openssl-dev \
  liblo-dev \
  libmad0-dev \
  frei0r-plugins-dev \
  libavdevice-dev \
  libfaad-dev \
  libglfw3-dev \
  protobuf-compiler \
  libuv1-dev \
  libxen-dev \
  libflac-dev \
  libpq-dev \
  libtheora-dev \
  libonig-dev \
  libglib2.0-dev \
  libgoocanvas-2.0-dev \
  libgtkspell3-3-dev \
  libpulse-dev \
  libdlm-dev \
  capnproto \
  libtorch-dev \
  libqrencode-dev \
  libshine-dev \
  libopus-dev \
  libspeex-dev \
  libvorbis-dev \
  libgstreamer1.0-dev \
  libgstreamer-plugins-base1.0-dev \
  liblz4-dev \
  liblilv-dev \
  libopenexr-dev \
  tmux \
  llvm \
  libclang-dev \
  libmaxminddb-dev \
  libsecp256k1-dev \
  libstring-shellquote-perl \
  ;

# create a non-root user
RUN useradd --create-home --shell /bin/bash --gid users --groups sudo user
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
USER user
WORKDIR /home/user

# set up opam
RUN opam init --disable-sandboxing --auto-setup

# make an opam switch for running benchmarks
RUN opam switch create bench 4.14.1
RUN opam install -y dune ocamlbuild camlp5

# make an opam switch for preparing the files for the benchmark
RUN opam switch create prepare 4.14.1
RUN opam install -y opam-monorepo ppx_sexp_conv ocamlfind ctypes ctypes-foreign re sexplib menhir camlp-streams zarith stdcompat refl

# Make the project directory and copy the opam lockfile to it. Other
# files will be copied later. We do this earlier than the rest because
# we're about to do the time-consuming `opam monorepo pull` step and
# we want it to depend on as little as possible.
RUN mkdir -p bench
WORKDIR bench
COPY --chown=user:users x.opam .
COPY --chown=user:users x.opam.locked .

# Running `opam monorepo pull` with a large package set is very likely to fail on at least
# one package in a non-deterministic manner. Repeating it several times reduces the chance
# that all attempts fail.
RUN opam monorepo pull || opam monorepo pull || opam monorepo pull

# Copy the patch directory
ADD --chown=user:users patches patches

# Prepare native sources for hacl-star
RUN . ~/.profile && cd duniverse/hacl-star/raw && ./configure && make -j

# Prepare why3
RUN . ~/.profile && \
  cd duniverse/why3 && \
  ./autogen.sh && \
  ./configure && \
  make coq.dune pvs.dune isabelle.dune src/util/config.ml

# Install camlp5 outside of opam
RUN . ~/.profile && \
  cd duniverse/camlp5 && \
  ./configure

# Prepare coq
RUN . ~/.profile && cd duniverse/coq && ./configure -no-ask

# Prepare clangml
RUN . ~/.profile && cd duniverse/clangml && ./configure

# Change to the benchmarking switch to run the benchmark
RUN opam switch bench

# Apply some custom packages to some packages
RUN bash -c 'for f in patches/*; do p=$(basename ${f%.diff}); echo Applying $p; patch -p1 -d duniverse/$p < $f; done'

# Initialize some projects' source code
RUN cd duniverse/zelus && ./configure
RUN rm -rf duniverse/magic-trace/vendor
RUN cd duniverse/ocurl && ./configure
RUN cd duniverse/elpi && make config LEGACY_PARSER=1
RUN cd duniverse/cpu && autoconf && autoheader && ./configure
RUN cd duniverse/setcore && autoconf && autoheader && ./configure
RUN cd duniverse/batsat-ocaml && ./build_rust.sh

# This is a hack to make hacl-star compile on aarch64 and x64.
# Different raw files get built depending on the architecture,
# and we want to depend on all available .ml files in the raw
# library.
RUN bash -c 'TARGETS=$(cd duniverse/hacl-star/raw/lib && ls *.ml | xargs); sed -i -e "s/__TARGETS__/$TARGETS/" duniverse/hacl-star/dune'

# async_ssl currently doesn't compile and is an optional dependency of some other packages
# that we want to build, so we have to delete it
RUN rm -r duniverse/async_ssl
RUN rm -r duniverse/coq-of-ocaml

COPY --chown=user:users dune-project .
COPY --chown=user:users dune .
COPY --chown=user:users hello.ml .
COPY --chown=user:users Makefile .

#RUN . ~/.profile && make hello || true
#COPY --chown=user:users test.json .
