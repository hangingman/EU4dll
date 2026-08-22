#!/usr/bin/env bash

set -eu

# GDB自身ではなく、起動するEU4だけへDLLをプリロードする。
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
eu4_bin=${EU4_BIN:-${HOME}/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4}
eu4_dll=${EU4_DLL:-$repo_root/libeu4dll.so}
trace_gdb=${TRACE_GDB:-$script_dir/trace_eu4_text_args.gdb}

if ! command -v gdb >/dev/null 2>&1; then
    printf 'error: gdb is required\n' >&2
    exit 1
fi
gdb_bin=$(command -v gdb)
if [ ! -x "$gdb_bin" ]; then
    printf 'error: gdb is not executable: %s\n' "$gdb_bin" >&2
    exit 1
fi

if [ ! -x "$eu4_bin" ]; then
    printf 'error: EU4 executable not found or not executable: %s\n' "$eu4_bin" >&2
    exit 1
fi

if [ ! -f "$eu4_dll" ]; then
    printf 'error: EU4 DLL not found: %s\n' "$eu4_dll" >&2
    exit 1
fi

if [ ! -f "$trace_gdb" ]; then
    printf 'error: GDB script not found: %s\n' "$trace_gdb" >&2
    exit 1
fi

# EU4_BINが相対パスでも、cd後に同じ実行ファイルを参照できるよう絶対化する。
eu4_bin=$(CDPATH= cd -- "$(dirname -- "$eu4_bin")" && pwd)/$(basename -- "$eu4_bin")
eu4_dll=$(CDPATH= cd -- "$(dirname -- "$eu4_dll")" && pwd)/$(basename -- "$eu4_dll")
trace_gdb=$(CDPATH= cd -- "$(dirname -- "$trace_gdb")" && pwd)/$(basename -- "$trace_gdb")
eu4_dir=$(dirname -- "$eu4_bin")

printf 'Tracing EU4 with %s\n' "$eu4_dll" >&2
printf 'EU4 remains running until it is closed by the user.\n' >&2

cd -- "$eu4_dir"
# GDBのshell経由起動と呼び出し元のLD_PRELOADを無効にし、inferiorへだけ設定する。
exec env -u LD_PRELOAD "$gdb_bin" -q -batch \
    -ex "set startup-with-shell off" \
    -ex "set environment LD_PRELOAD=$eu4_dll" \
    -x "$trace_gdb" \
    --args "$eu4_bin" "$@"
