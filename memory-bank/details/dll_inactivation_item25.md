# DLL inactivation after 16:07 JST (item 25, 2026-11-21)

## Symptom

From the item 23 runs onwards (first failing run: runs/20261121-163222),
EU4 launched by eu4_smoke.sh / eu4_multiplayer.sh with
LD_PRELOAD=libeu4dll.so produced no [DIAGNOSTIC-RAW] lines at all and no
fresh pattern_eu4jps.log, although the same .so file and the same EU4
binary had worked in every run up to runs/20261121-160731-multiplayer
(item 21, started 16:07). Item 24 also noted that a bare
LD_PRELOAD of the .so into /bin/true produced no diagnostic output.

## Root cause (proven by reproduction, 2026-11-21 17:05-17:12 JST)

`make test` overwrites libeu4dll.so with a unittest build, and that
build's entry point is a no-op:

- The Makefile `test` target runs `dub build --build=unittest
  --compiler=ldc2` for the default `eu4dll` configuration, whose target
  is the same libeu4dll.so file as the normal build.
- In dllmain.d, `hijack()` (pragma(crt_constructor)) is compiled to a
  NOP under `version (unittest)`, so a unittest-built .so loads
  silently: no DIAGNOSTIC-RAW write, no pattern_eu4jps.log, no hooks.
  The EU4 process itself runs completely normally (vanilla behaviour),
  which is why the failure looked like "the DLL stopped activating"
  rather than a crash.
- Measured before/after on the same working tree:
  - Normal build: md5 2e645e64952315dacad5ed762024a6dd.
    `LD_PRELOAD=libeu4dll.so /bin/true` prints the DIAGNOSTIC-RAW
    crt_constructor / hijackProcess lines (and exits 255 via the
    PluginVersion gate, as expected for a non-EU4 process).
  - After `make test`: md5 24a49710b4b6eeee5042b9da6958a633, mtime
    15:59:37 (the cached unittest artifact). The same /bin/true preload
    prints nothing and exits 0. This md5 is exactly the value item 24
    recorded for the .so during the failing period ("built 15:59"),
    and the mtime is 11 seconds before the normal build's 15:59:48,
    which is why the file looked unchanged.
  - `make all` afterwards restores the normal build (md5 back to
    2e645e...), even though dub prints "up to date".

## Why it bit at 16:07-16:32 and kept biting

Item 20 had already hit the same trap once (runs/20261121-153821, noted
in PROGRESS.md: "always finish with make all before a smoke run").
Items 22-24 each ran `make test` as part of their verification, and
their smoke runs were executed while the unittest build was in place
(item 23 smokes at 16:32/16:36/16:40/16:44, item 24 smoke at 16:55).
The closing `make all` of one item did not protect the next item's
smokes once that item ran `make test` again before or between them.
Nothing about the EU4 binary, the smoke scripts, LD_PRELOAD, settings,
or the .so source changed; the EU4 binary md5
(ba1e6957fff90d306e3f40a5388fc925) and the smoke script are untouched.

## Rule going forward

- After any `make test`, always run `make all` and verify the .so is
  the normal build before a smoke run. Cheap check:
  `LD_PRELOAD=$PWD/libeu4dll.so /bin/true` must print the two
  DIAGNOSTIC-RAW lines (stderr). If it prints nothing, the .so is a
  unittest build.
- A smoke run with zero DIAGNOSTIC-RAW lines means "DLL never ran";
  do not draw conclusions about patches or fonts from such a run.
  In particular, item 24's blocker 2 (120,880 Invalid character ID
  lines) is NOT yet evidence about the item 17 limiter patch, because
  the DLL was inactive in every run that produced that count with the
  generated fonts. Item 26 must re-check it with an active DLL.

## Restoration verified

Smoke runs/20261121-170719 with EU4DLL_ENABLE_DECODE=1,
EU4DLL_SETTEXT_PROBE=1, EU4DLL_SETTEXT_REPLACEMENTS="Back=Home":
DIAGNOSTIC-RAW crt_constructor / hijackProcess / SetText probe lines
present, fresh pattern_eu4jps.log with SetText mapping id=0
result=applied, DLL [OK] count 1, ended_by_exit_button, eu4_wait=0.
Menu screenshot shot_menu.png checked visually: normal English main
menu, no corruption.
