#!/usr/bin/env bash

set -e

name="$(basename ${0})"

: ${TOP_DIR:="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}

source ${TOP_DIR}/util-common.sh

usage() {
	echo "${name} - Builds Debian kernel." >&2
	echo "Usage: ${name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -b --build-only   - Only run (2nd) build step." >&2
	echo "  -d --dry-run      - Do not run commands." >&2
	echo "  -h --help         - Show this help and exit." >&2
	echo "  -i --build-id     - Build id. Default: '${build_id}'." >&2
	echo "  -k --kernel-src   - Kernel source directory. Default: '${kernel_src}'." >&2
	echo "  -s --setup-only   - Only run (1st) setup step." >&2
	echo "  -v --verbose      - Verbose execution." >&2
	echo "  -w --work-dir     - Build directory. Default: '${work_dir}'." >&2
	echo "Info:" >&2
	echo "  ${cpus} CPUs available." >&2
	echo "Examples:" >&2
	echo "  ${name} --setup-only" >&2
	echo "  <edit source files, add patches, etc.>" >&2
	echo "  ${name} --build-only" >&2
}

short_opts="bdhi:k:svw:"
long_opts="build-only,dry-run,help,build-id:,kernel-src:,setup-only,verbose,work-dir:"

opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${name}" -- "$@")

if [ $? != 0 ]; then
	echo "${name}: ERROR: Internal getopt" >&2 
	exit 1
fi

eval set -- "${opts}"

while true ; do
	case "${1}" in
	-b | --build-only)
		build_only=1
		shift
		;;
	-d | --dry-run)
		dry_run=1
		shift
		;;
	-h | --help)
		usage=1
		shift
		;;
	-i | --build-id)
		build_id="${2}"
		shift 2
		;;
	-k | --kernel-src)
		kernel_src="${2}"
		shift 2
		;;
	-s | --setup-only)
		setup_only=1
		shift
		;;
	-v | --verbose)
		set -x
		verbose=1
		shift
		;;
	-w | --work-dir)
		work_dir="${2}"
		shift 2
		;;
	--)
		shift
		break
		;;
	*)
		echo "${name}: ERROR: Internal opts" >&2 
		exit 1
		;;
	esac
done

cmd_trace=1
cpus="$(cpu_count)"

if [[ -z "${work_dir}" ]]; then
	work_dir="$(pwd)"
fi

check_src() {
	if [[ ! -d "${1}" ]]; then
		echo "${name}: ERROR: bad <kernel-src>: '${1}'" >&2 
		usage
		exit 1
	fi
}

check_revision() {
	if [[ ! -d "/usr/src/linux-${1}" ]]; then
		echo "${name}: ERROR: bad revision: '${1}'" >&2 
		usage
		exit 1
	fi
}

if [[ -z "${kernel_src}" ]]; then
	kernel_src="/usr/src/$(echo /usr/src/linux-[0-9]* | egrep -o 'linux-[.0-9]*$')"
fi

if [[ -n "${usage}" ]]; then
	usage
	exit 0
fi

check_src "${kernel_src}"
revision=$(echo "${kernel_src}" | egrep -o '[.0-9]*$')
check_revision ${revision}

build="build-linux-${revision}${build_id}"
build_dir="$(pwd)/${build}"

if [[ ! ${build_only} ]]; then
	run_cmd "mkdir -p ${build_dir}"
	run_cmd "ln -s ${build} current-linux-build"

	run_cmd "rsync -av --delete ${kernel_src}/ ${build_dir}/"
	run_cmd "chown -R $(id -u):$(id -g) ${build_dir}"

	run_cmd "cd ${build_dir}"

	run_cmd "quilt pop -a"
	run_cmd "quilt push -a"

	run_cmd "make -f debian/rules.gen setup_arm64_none"
	run_cmd "cp debian/build/build_arm64_none_arm64/.config ./"
	run_cmd "make oldconfig"
	run_cmd "make savedefconfig"

	echo "${name}: Success, setup ${build_dir}"
fi

if [[ ! ${setup_only} ]]; then
	run_cmd "cd ${build_dir}"

	run_cmd "quilt pop -a"
	run_cmd "quilt push -a"

	run_cmd "make -f debian/rules.gen setup_arm64_none"
	run_cmd "cp debian/build/build_arm64_none_arm64/.config ${build_dir}/"
	run_cmd "make oldconfig"
	run_cmd "CCACHE_DIR=$(pwd)/.ccache make CROSS_COMPILE='ccache ' -j${cpus}"
	run_cmd "make savedefconfig"

	echo "${name}: Success, built ${kernel_src} in ${build_dir}"
fi
