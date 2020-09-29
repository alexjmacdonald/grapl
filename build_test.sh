#!/usr/bin/env bash

DIST_DIR=hot_dist
mkdir -p ${DIST_DIR}/{rust,python/{venv,builds},js} 2>/dev/null

#
# Rust
#

build-rust() {
  cat <<'EOF' | docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t "grapl-rust-build-hotness" -
FROM rust:1.46-slim-buster

RUN apt-get update && apt-get install -y apt-utils musl musl-dev musl-tools wget

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID -o grapl && \
  adduser --disabled-password --gecos '' --home /grapl --shell /bin/bash --uid $UID --gid $GID grapl
USER grapl
WORKDIR /grapl

RUN rustup target add x86_64-unknown-linux-musl
EOF

  docker run --rm -it \
    --env RUSTC_WRAPPER=sccache \
    --mount type=bind,source=${HOME}/.cache/sccache,target=/grapl/.cache/sccache \
    --mount type=bind,source=$(which sccache),target=/usr/bin/sccache,readonly \
    --mount type=bind,source=${PWD}/src/rust/Cargo.toml,target=/grapl/Cargo.toml,readonly \
    --mount type=bind,source=${PWD}/src/rust/Cargo.lock,target=/grapl/Cargo.lock,readonly \
    --mount type=bind,source=${PWD}/src/rust/analyzer-dispatcher,target=/grapl/analyzer-dispatcher,readonly \
    --mount type=bind,source=${PWD}/src/rust/derive-dynamic-node,target=/grapl/derive-dynamic-node,readonly \
    --mount type=bind,source=${PWD}/src/rust/generic-subgraph-generator,target=/grapl/generic-subgraph-generator,readonly \
    --mount type=bind,source=${PWD}/src/rust/graph-descriptions,target=/grapl/graph-descriptions,readonly \
    --mount type=bind,source=${PWD}/src/rust/graph-generator-lib,target=/grapl/graph-generator-lib,readonly \
    --mount type=bind,source=${PWD}/src/rust/graph-merger,target=/grapl/graph-merger,readonly \
    --mount type=bind,source=${PWD}/src/rust/grapl-config,target=/grapl/grapl-config,readonly \
    --mount type=bind,source=${PWD}/src/rust/grapl-observe,target=/grapl/grapl-observe,readonly \
    --mount type=bind,source=${PWD}/src/rust/metric-forwarder,target=/grapl/metric-forwarder,readonly \
    --mount type=bind,source=${PWD}/src/rust/node-identifier,target=/grapl/node-identifier,readonly \
    --mount type=bind,source=${PWD}/src/rust/sysmon-subgraph-generator,target=/grapl/sysmon-subgraph-generator,readonly \
    --mount type=bind,source=${PWD}/${DIST_DIR}/rust,target=/grapl/target \
    -t grapl-rust-build-hotness \
    bash -c "cargo build --target=x86_64-unknown-linux-musl && sccache -s"
}

#
# Python
#

build-python() {
  cat <<'EOF' | docker build --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t "grapl-python-build-hotness" -
FROM python:3.7-slim-buster

RUN apt-get update && apt-get -y install --no-install-recommends musl-dev protobuf-compiler build-essential zip bash

ARG UID=1000
ARG GID=1000
RUN groupadd -g $GID -o grapl && \
  adduser --disabled-password --gecos '' --home /grapl --shell /bin/bash --uid $UID --gid $GID grapl
USER grapl
WORKDIR /grapl

ENV PROTOC /usr/bin/protoc
ENV PROTOC_INCLUDE /usr/include
EOF

  # venv setup
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    -t grapl-python-build-hotness \
    bash -c "python3 -mvenv venv && source venv/bin/activate && pip install --upgrade pip && \
      pip install wheel grpcio chalice hypothesis pytest pytest-xdist"

  # analyzer-deployer
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/analyzer-deployer,target=/grapl/analyzer-deployer,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r analyzer-deployer/requirements.txt && \
      python -m mypy_boto3 && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/analyzer-deployer.zip . && cd && \
      zip -g ~/dist/analyzer-deployer.zip ~/analyzer-deployer/analyzer_deployer/app.py"

  # analyzer-executor
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/analyzer_executor,target=/grapl/analyzer_executor,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r analyzer_executor/requirements.txt && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/analyzer-executor.zip . && cd && \
      zip -g ~/dist/analyzer-executor.zip ~/analyzer_executor/src/analyzer-executor.py"

  # engagement-creator
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/engagement-creator,target=/grapl/engagement-creator,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r engagement-creator/requirements.txt && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/engagement-creator.zip . && cd && \
      zip -g ~/dist/engagement-creator.zip ~/engagement-creator/src/engagement-creator.py"

  # engagement_edge
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/engagement_edge,target=/grapl/engagement_edge,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r engagement_edge/requirements.txt && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/engagement_edge.zip . && cd && \
      zip -g ~/dist/engagement_edge.zip ~/engagement_edge/src/engagement_edge.py"

  # dgraph-ttl
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/grapl-dgraph-ttl,target=/grapl/grapl-dgraph-ttl,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r grapl-dgraph-ttl/requirements.txt && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/dgraph-ttl.zip . && cd && \
      zip -g ~/dist/dgraph-ttl.zip ~/grapl-dgraph-ttl/app.py"

  # model-plugin-deployer
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/venv,target=/grapl/venv \
    --mount type=bind,source=${PWD}/${DIST_DIR}/python/builds,target=/grapl/dist \
    --mount type=bind,source=${PWD}/src/python/grapl-model-plugin-deployer,target=/grapl/grapl-model-plugin-deployer,readonly \
    -t grapl-python-build-hotness \
    bash -c "source venv/bin/activate && \
      pip install -r grapl-model-plugin-deployer/requirements.txt && \
      cd ~/venv/lib/python3.7/site-packages && zip --quiet -9r ~/dist/model-plugin-deployer.zip . && cd && \
      zip -g ~/dist/model-plugin-deployer.zip ~/grapl-model-plugin-deployer/src/grapl_model_plugin_deployer.py"
}

build-js() {
  # graphql_endpoint
  cat <<'EOF' | docker build -t "grapl-graphql-build-hotness" -
FROM node:12.18-buster-slim


RUN apt-get update && apt-get -y install --no-install-recommends build-essential libffi-dev libssl-dev python3 zip
USER node
WORKDIR /home/node
EOF
  docker run --rm -it \
    --mount type=bind,source=${PWD}/${DIST_DIR}/js,target=/home/node/dist \
    --mount type=bind,source=${PWD}/src/js/graphql_endpoint,target=/home/node/graphql_endpoint \
    -t grapl-graphql-build-hotness \
    bash -c "cd graphql_endpoint && rm -rf node_modules && npm i && \
      mkdir ~/lambda && \
      cp -r ~/graphql_endpoint/node_modules/ ~/lambda/ && \
      cp -r ~/graphql_endpoint/modules/ ~/lambda/ && \
      cp -r ~/graphql_endpoint/server.js ~/lambda/ && \
      cd ~/lambda && zip --quiet -9r ~/dist/graphql_endpoint.zip ."
}

build-rust
build-python
build-js