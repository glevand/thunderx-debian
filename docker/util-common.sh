#!/usr/bin/env bash

[[ "$(uname -m)" == "aarch64" ]] || (echo "Must run on arm64 machine"; exit 1)

: ${DOCKER_NAME:="buster-kernel-builder"}
: ${VERSION:="1"}
: ${ARCH_TAG:="arm64"}
: ${DOCKER_TAG:="${DOCKER_NAME}:${VERSION}${ARCH_TAG}"}

show_tag () {
	echo "${DOCKER_TAG}"
}
