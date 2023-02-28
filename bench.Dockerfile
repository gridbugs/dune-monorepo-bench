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
  libopenblas-dev \
  qt5-qmake \
  libqt5quick5 \
  qtdeclarative5-dev \
  libgpiod-dev \
  libzstd-dev \
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
RUN opam install -y dune ocamlbuild

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

# Prepare clangml
RUN . ~/.profile && cd duniverse/clangml && ./configure

# Change to the benchmarking switch to run the benchmark
RUN opam switch bench

# Apply some custom packages to some packages
RUN bash -c 'for f in patches/*; do p=$(basename ${f%.diff}); echo Applying $p; patch -p1 -d duniverse/$p < $f; done'

# Initialize some projects' source code
RUN cd duniverse/zelus && ./configure
RUN rm -rf duniverse/magic-trace/vendor
RUN cd duniverse/cpu && autoconf && autoheader && ./configure
RUN cd duniverse/setcore && autoconf && autoheader && ./configure
RUN cd duniverse/batsat-ocaml && ./build_rust.sh

# Some packages define conflicting definitions of libraries so they must be removed for the build to succeed
RUN rm -r duniverse/coq-of-ocaml

COPY --chown=user:users dune-project .
COPY --chown=user:users dune .
COPY --chown=user:users hello.ml .
COPY --chown=user:users Makefile .
ADD --chown=user:users bin bin

#RUN . ~/.profile && make hello || true
#COPY --chown=user:users test.json .
