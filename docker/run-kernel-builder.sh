#!/usr/bin/env bash

set -e

name="$(basename $0)"

: ${TOP_DIR:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}

source ${TOP_DIR}/docker/util-common.sh

docker_user_flags="-u $(id -u):$(id -g)"
#docker_flags=${docker_user_flags}

: ${WORK_DIR:="$(pwd)/work"}
mkdir -p ${WORK_DIR}

docker run --rm -it \
	${docker_flags} \
	-v /etc/group:/etc/group:ro \
	-v /etc/passwd:/etc/passwd:ro \
	-v ${WORK_DIR}:/work \
	-w /work \
	${DOCKER_TAG}
