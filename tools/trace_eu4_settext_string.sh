#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
trace_gdb=${TRACE_GDB:-$script_dir/trace_eu4_settext_string.gdb}

printf 'Tracing limited SetText CString strings with %s\n' "${EU4_BIN:-${HOME}/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4}" >&2
printf 'This reads at most five bounded byte sequences; GDB cannot guarantee arbitrary-pointer readability, so a read failure may stop GDB/EU4.\n' >&2

TRACE_GDB=$trace_gdb exec "$script_dir/trace_eu4_text_with_dll.sh" "$@"
