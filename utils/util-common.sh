#!/usr/bin/env bash

run_cmd() {
	local cmd="${*}"

	if [[ -n ${cmd_trace} ]]; then
		echo "==> ${cmd}"
	fi

	if [[ -n "${dry_run}" ]]; then
		true
	else
		eval "${cmd}"
	fi
}

cpu_count() {
	echo "$(getconf _NPROCESSORS_ONLN || echo 1)"
}
