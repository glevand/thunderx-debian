#!/usr/bin/env bash

set -e

name="$(basename ${0})"

: ${TOP_DIR:="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"}

source ${TOP_DIR}/util-common.sh

usage() {
	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${name} - Builds Debian kernel." >&2
	echo "Usage: ${name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -d --dry-run      - Do not run commands." >&2
	echo "  -h --help         - Show this help and exit." >&2
	echo "  -i --build-id     - Build id. Default: '${build_id}'." >&2
	echo "  -k --kernel-src   - Kernel source directory. Default: '${kernel_src}'." >&2
	echo "  -v --verbose      - Verbose execution." >&2
	echo "  -w --work-dir     - Working directory. Default: '${work_dir}'." >&2
	echo "Option steps:" >&2
	echo "  -1 --setup-source - Run setup source step. Default: '${step_setup_source}'." >&2
	echo "  -2 --run-quilt    - Run quilt step. Default: '${step_run_quilt}'." >&2
	echo "  -3 --build-kernel - Run build kernel step. Default: '${step_build_kernel}'." >&2
	echo "Info:" >&2
	echo "  ${cpus} CPUs available." >&2
	echo "Examples:" >&2
	echo "  ${name} --setup-source" >&2
	echo "  # edit source files, add patches, etc." >&2
	echo "  ${name} --run-quilt --build-kernel" >&2
	eval "${old_xtrace}"
}

short_opts="dhi:k:vw:12"
long_opts="dry-run,help,build-id:,kernel-src:,verbose,work-dir:,setup-source,run-quilt,build-kernel"

opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${name}" -- "$@")

if [ $? != 0 ]; then
	echo "${name}: ERROR: Internal getopt" >&2
	exit 1
fi

eval set -- "${opts}"

while true ; do
	case "${1}" in
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
	-v | --verbose)
		export PS4='\[\033[0;33m\]+$(basename ${BASH_SOURCE}):${LINENO}: \[\033[0;37m\]'
		set -x
		verbose=1
		shift
		;;
	-w | --work-dir)
		work_dir="${2}"
		shift 2
		;;
	-1 | --setup-source)
		step_setup_source=1
		shift
		;;
	-2 | --run-quilt)
		step_run_quilt=1
		shift
		;;
	-3 | --build-kernel)
		step_build_kernel=1
		shift
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

if [[ ${kernel_src} ]]; then
	if [[ ! -d ${kernel_src} ]]; then
		echo "${name}: ERROR: bad <kernel-src>: '${kernel_src}'" >&2
		usage
		exit 1
	fi
else
	kernel_src=$(find /usr/src/ -maxdepth 1 -type d -name 'linux-[4-6].[0-9]*')
	
	if [[ ! ${kernel_src} ]]; then
		echo "${name}: ERROR: No kernel sources found in '/usr/src/'. Use --kernel-src option." >&2
		usage
		exit 1
	fi

	if [ $(echo "${kernel_src}" | wc -l) -gt 1 ]; then
		echo "${name}: ERROR: Multiple kernel sources found in '/usr/src/'. Use --kernel-src option." >&2
		usage
		exit 1
	fi
fi

config_arm64="${kernel_src}/debian/config/arm64"

if [[ ! -d "${config_arm64}" ]]; then
	echo "${name}: ERROR: No '${config_arm64}' found." >&2
	usage
	exit 1
fi

if [[ -n "${usage}" ]]; then
	usage
	exit 0
fi

base_name="$(basename ${kernel_src})${build_id}"
build_dir="${work_dir}/${base_name}--build"
install_dir="${work_dir}/${base_name}--install"
ccache_dir="${work_dir}/${base_name}--ccache"

step_code="${step_setup_source}-${step_run_quilt}-${step_build_kernel}"
case "${step_code}" in
1--|1-1-|1-1-1|-1-|-1-1|--1)
	#echo "${name}: Steps OK" >&2
	;;
--)
	step_setup_source=1
	step_run_quilt=1
	step_build_kernel=1
	;;
1--1)
	echo "${name}: ERROR: Bad flags: 'setup_source + build_kernel'." >&2
	usage
	exit 1
	;;
*)
	echo "${name}: ERROR: Internal bad step_code: '${step_code}'." >&2
	exit 1
	;;
esac

if [[ ${step_setup_source} ]]; then
	if [[ ${verbose} ]]; then
		rsync_extra="-v"
	fi

	run_cmd "rm -rf ${install_dir}"
	run_cmd "mkdir -p ${build_dir}"

	run_cmd "cd ${work_dir}"
	run_cmd "ln -sfT $(basename ${build_dir}) current-linux-build"


	run_cmd "rsync -a ${rsync_extra} --delete --exclude=${ccache_dir} ${kernel_src}/ ${build_dir}/"
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

if [[ ${step_run_quilt} ]]; then
	run_cmd "cd ${build_dir}"

	run_cmd "quilt pop -a"
	run_cmd "quilt push -a"

	run_cmd "make -f debian/rules.gen setup_arm64_none"
	run_cmd "cp debian/build/build_arm64_none_arm64/.config ${build_dir}/"
	run_cmd "make oldconfig"
	run_cmd "make savedefconfig"
fi

if [[ ${step_build_kernel} ]]; then
	make_opts="CROSS_COMPILE='ccache ' INSTALL_MOD_PATH='${install_dir}' INSTALL_PATH='${install_dir}/boot' -j${cpus}"

	run_cmd "rm -rf ${install_dir}"
	run_cmd "mkdir -p ${install_dir}/boot ${install_dir}/lib/modules"

	run_cmd "cd ${build_dir}"

	run_cmd "make clean"
	run_cmd "CCACHE_DIR=${ccache_dir} make ${make_opts}"
#	run_cmd "CCACHE_DIR=${ccache_dir} make ${make_opts} install"
	run_cmd "CCACHE_DIR=${ccache_dir} make ${make_opts} modules_install"
	run_cmd "make savedefconfig"

	run_cmd "cp --no-dereference ${build_dir}/{defconfig,System.map,vmlinux} ${install_dir}/boot/"
	run_cmd "cp --no-dereference ${build_dir}/arch/arm64/boot/Image ${install_dir}/boot/"
	run_cmd "cp --no-dereference ${build_dir}/.config ${install_dir}/boot/config"

	echo "${name}: Success, built ${kernel_src} in ${build_dir}"
fi
