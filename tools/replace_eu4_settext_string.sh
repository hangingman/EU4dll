#!/usr/bin/env bash

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ "${EU4DLL_SETTEXT_REPLACEMENTS+x}" != x ] && \
   { [ "${EU4DLL_SETTEXT_SOURCE+x}" != x ] || [ "${EU4DLL_SETTEXT_REPLACEMENT+x}" != x ]; }; then
    printf '%s\n' 'SetText PoC disabled: set EU4DLL_SETTEXT_REPLACEMENTS or the legacy source/replacement pair.' >&2
else
    printf '%s\n' "SetText PoC mappings: use EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Foo=Bar' (exactly one '=' per entry)." >&2
fi
if [ "${EU4DLL_SETTEXT_APPLY:-}" = 1 ]; then
    printf '%s\n' 'SetText PoC apply mode: one equal-length, writable-buffer hit may be replaced.' >&2
else
    printf '%s\n' 'SetText PoC observation mode: no game memory is modified.' >&2
fi
printf '%s\n' 'Values are UTF-8 byte strings; only one exact match per mapping and equal byte lengths are eligible.' >&2
printf '%s\n' 'Variable-length replacements, such as Back=戻る, are skipped; no CString pointer or length is changed.' >&2
printf '%s\n' 'The native bounded probe additionally requires EU4DLL_SETTEXT_PROBE=1; this workflow never enables it implicitly.' >&2
printf '%s\n' 'Real EU4 replacement remains unverified; stop the run if any uncertainty or crash occurs.' >&2

TRACE_GDB=$script_dir/replace_eu4_settext_string.gdb \
    exec "$script_dir/trace_eu4_text_with_dll.sh" "$@"
