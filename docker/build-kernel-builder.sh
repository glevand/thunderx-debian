#!/usr/bin/env bash

set -e

name="$(basename ${0})"

: ${TOP_DIR:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}

source ${TOP_DIR}/docker/docker-common.sh

: ${DOCKER_FILE:="${TOP_DIR}/docker/Dockerfile.arm64"}

usage () {
	echo "${name} - Builds a docker image with tools to build the Debian 10 Buster kernel." >&2
	echo "Usage: ${name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help     - Show this help and exit." >&2
	echo "  -p --purge    - Remove existing docker image and rebuild." >&2
	echo "  -r --rebuild  - Rebuild existing docker image." >&2
	echo "  -t --tag      - Print Docker tag to stdout and exit." >&2
	echo "  -v --verbose  - Verbose execution." >&2
	echo "Environment:" >&2
	echo "  VERSION       - Default: '${VERSION}'" >&2
	echo "  DOCKER_FILE   - Default: '${DOCKER_FILE}'" >&2
	echo "  DOCKER_TAG    - Default: '${DOCKER_TAG}'" >&2
}

short_opts="hprtv"
long_opts="help,purge,rebuild,tag,verbose"

opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${name}" -- "$@")

if [ $? != 0 ]; then
	echo "${name}: Terminating..." >&2 
	exit 1
fi

eval set -- "${opts}"

while true ; do
	case "${1}" in
	-h | --help)
		usage=1
		shift
		;;
	-p | --purge)
		purge=1
		shift
		;;
	-r | --rebuild)
		rebuild=1
		shift
		;;
	-t | --tag)
		show_tag
		exit 0
		;;
	-v | --verbose)
		set -x
		verbose=1
		shift
		;;
	--)
		shift
		break
		;;
	*)
		echo "Error: Unknown option '${1}'." >&2
		usage
		exit 1
		;;
	esac
done

if [[ -n "${usage}" ]]; then
	usage
	exit 0
fi

if [[ -n "${purge}" ]] && docker inspect --type image ${DOCKER_TAG} >/dev/null 2>/dev/null; then
	echo "Removing docker image: ${DOCKER_TAG}" >&2
	docker rmi --force ${DOCKER_TAG}
elif [[ -z "${rebuild}" ]] && docker inspect --type image ${DOCKER_TAG} >/dev/null 2>/dev/null; then
	echo "Docker image exists: ${DOCKER_TAG}" >&2
	show_tag
	exit 0
fi

echo "Building docker image: ${DOCKER_TAG}" >&2

cd ${TOP_DIR}/docker

docker build \
	--file=${DOCKER_FILE} \
	--tag=${DOCKER_TAG} \
	.

show_tag
