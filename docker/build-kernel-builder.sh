#!/usr/bin/env bash

set -e

name="$(basename $0)"

: ${TOP_DIR:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}

source ${TOP_DIR}/docker/util-common.sh

cd ${TOP_DIR}

docker build \
	--file=./docker/Dockerfile.arm64 \
	--tag=${DOCKER_TAG} \
	.
