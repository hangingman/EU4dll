#!/usr/bin/env bash

set -eu

eu4_bin=${EU4_BIN:-${HOME}/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4}

if ! command -v gdb >/dev/null 2>&1; then
    printf 'error: gdb is required\n' >&2
    exit 1
fi

if [ ! -x "$eu4_bin" ]; then
    printf 'error: EU4 executable not found or not executable: %s\n' "$eu4_bin" >&2
    printf 'Set EU4_BIN to the v1.37.5 executable path.\n' >&2
    exit 1
fi

printf 'Tracing candidate CString addresses in %s\n' "$eu4_bin" >&2
printf 'This records addresses only; it does not read candidate memory or patch the process.\n' >&2

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
gdb -q -batch -x "$script_dir/trace_eu4_text_args.gdb" --args "$eu4_bin" "$@"
