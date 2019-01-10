#!/usr/bin/env bash

set -e

name="$(basename ${0})"

TOP_DIR=${TOP_DIR:="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}
WORK_DIR=${WORK_DIR:="$(pwd)/buster-kernel-work"}

source ${TOP_DIR}/docker/docker-common.sh

docker_host="buster-kernel-builder"
docker_name="buster-kernel-builder"

usage () {
	echo "${name} - Enters an interactive '${DOCKER_TAG}' container session." >&2
	echo "Usage: ${name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -h --help           - Show this help and exit." >&2
	echo "  -o --host <host>    - Container hostname. Default: '${docker_host}'" >&2
	echo "  -n --name <name>    - Container name. Default: '${docker_name}'" >&2
	echo "  -u --user <uid:gid> - Enter container as user. Default: '${docker_user}'." >&2
	echo "  -v --verbose        - Verbose execution." >&2
	echo "Environment:" >&2
	echo "  DOCKER_TAG - Default: '${DOCKER_TAG}'" >&2
	echo "  WORK_DIR   - Default: '${WORK_DIR}'" >&2
}

short_opts="ho:n:u:v"
long_opts="help,host:,name:,user:,verbose"

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
	-o | --host)
		docker_host="${2}"
		shift 2
		;;
	-n | --name)
		docker_name="${2}"
		shift 2
		;;
	-u | --user)
		docker_user="${2}"
		shift 2
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

if [[ -z "${docker_user}" ]]; then
	docker_user="$(id -u):$(id -g)"
fi

if [[ -n "${usage}" ]]; then
	usage
	exit 0
fi

if [[ -n "${docker_host}" ]]; then
	docker_flags+=" --hostname=${docker_host}"
fi

if [[ -n "${docker_name}" ]]; then
	docker_flags+=" --name=${docker_name}"
fi

if [[ -n "${docker_user}" ]]; then
	docker_flags+=" --user=${docker_user}"
fi

mkdir -p ${WORK_DIR}

docker run --rm -it \
	${docker_flags} \
	--volume=/etc/group:/etc/group:ro \
	--volume=/etc/passwd:/etc/passwd:ro \
	--volume=${TOP_DIR}:/"$(basename ${TOP_DIR})" \
	--volume=${WORK_DIR}:/work \
	--workdir=/work \
	${DOCKER_TAG}
