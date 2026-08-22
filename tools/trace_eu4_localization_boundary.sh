#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
trace_gdb=${TRACE_GDB:-$script_dir/trace_eu4_localization_boundary.gdb}

if [ "${EU4DLL_SKIP_TRANSLATIONS:-}" = "1" ]; then
    printf 'Tracing localisation boundaries with translations skipped\n' >&2
else
    printf 'Tracing localisation boundaries with translations enabled\n' >&2
fi

# Reuse the DLL-aware launcher; EU4DLL_SKIP_TRANSLATIONS is inherited unchanged.
TRACE_GDB=$trace_gdb exec "$script_dir/trace_eu4_text_with_dll.sh" "$@"
