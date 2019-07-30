#!/usr/bin/env bash

usage() {
	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace
	echo "${name} - Select PCI device." >&2
	echo "Usage: ${name} [flags]" >&2
	echo "Option flags:" >&2
	echo "  -d --dry-run      - Do not run commands." >&2
	echo "  -h --help         - Show this help and exit." >&2
	echo "  -v --verbose      - Verbose execution." >&2
	eval "${old_xtrace}"
}

process_opts() {
	local short_opts="dhv"
	local long_opts="dry-run,help,verbose,"

	local opts
	opts=$(getopt --options ${short_opts} --long ${long_opts} -n "${name}" -- "$@")

	eval set -- "${opts}"

	while true ; do
		#echo "${FUNCNAME[0]}: @${1}@ @${2}@"
		case "${1}" in
		-d | --dry-run)
			dry_run=1
			shift
			;;
		-h | --help)
			usage=1
			shift
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
			echo "${name}: ERROR: Internal opts" >&2
			exit 1
			;;
		esac
	done
}

on_exit() {
	local result=${1}

	set +x
	echo "${name}: Done: ${result}" >&2
}

print_list() {
	local -n _print_list__array=${1}

	local old_xtrace="$(shopt -po xtrace || :)"
	set +o xtrace

	for ((i = 0; i < ${#_print_list__array[@]}; i++)); do
		echo -e " ($((${i} + 1)))\t${_print_list__array[i]}"
	done

	eval "${old_xtrace}"
}

get_index() {
	local -n _get_index__array=${1}
	local -n _get_index__index=${2}
	local selection

	while true; do
		read -p "Select device (1-${#_get_index__array[@]}): " selection
		selection="${selection:0:2}"

		if [[ ${selection} -ge 1 && ${selection} -le ${#_get_index__array[@]} ]]; then
			break
		fi
		echo "Enter integer value (1-${#_get_index__array[@]})."
	done

	_get_index__index="$((selection - 1))"

	#echo "=> (${selection}) ${_get_index__array[_get_index__index]})"
}

#===============================================================================
# program start
#===============================================================================
export PS4='\[\033[0;33m\]+${BASH_SOURCE##*/}:${LINENO}: \[\033[0;37m\]'
set -e

name="${0##*/}"
trap "on_exit 'failed.'" EXIT

SCRIPTS_TOP=${SCRIPTS_TOP:-"$(cd "${BASH_SOURCE%/*}" && pwd)"}
source ${SCRIPTS_TOP}/util-common.sh

process_opts "${@}"

if [[ ${usage} ]]; then
	usage
	trap - EXIT
	exit 0
fi

if ! test -x "$(command -v lspci)"; then
	echo "${name}: ERROR: Please install lspci (pciutils)'." >&2
	exit 1
fi

IFS=$'\n'
data_array=($(lspci -mm))

print_list data_array
get_index data_array index

item=${data_array[index]}
device=${item%% *}

echo "=> index  = ${index}" >&2
echo "=> item   = '${item}'" >&2
echo "=> device = '${device}'" >&2

trap "on_exit 'Success.'" EXIT
