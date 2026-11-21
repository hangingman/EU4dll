# Preload guard: stay inert outside the EU4 process

## Problem

Steam starts EU4 through a chain of helper processes (the Paradox
launcher, Steam runtime tools such as the reaper and pressure-vessel
wrappers), and an `LD_PRELOAD` launch option puts libeu4dll.so into
every one of them. The DLL's crt_constructor ran hijackProcess()
unconditionally, and hijackProcess() ends in `exit(-1)` when
PluginVersion.init fails. Outside the game the version check always
fails (Misc.getVersion finds no EU4 version pattern), so every helper
process died the moment it loaded the DLL and the game never started.
There were no logs: the helpers died before the game's own logging
existed, and the DLL's log file was created in the helper's working
directory, not anywhere the owner looked.

Measured before the fix (both the owner's build and the hatch build):
`LD_PRELOAD=<libeu4dll.so> /bin/true` exited with 255, and
`/bin/echo` printed nothing and also exited 255.

## Fix

Branch work/preload-guard, source/plugin/dllmain.d only.

- New pure function `isEu4ExecutablePath(string)`: true when the
  basename of the given executable path is exactly "eu4".
- New wrapper `currentProcessIsEu4()`: feeds it
  `std.file.thisExePath()` (which reads /proc/self/exe). If the path
  cannot be determined, the process is treated as not EU4, so the DLL
  stays inert rather than risking an exit(-1) in an unknown host.
  (Note: in this Phobos version thisExePath lives in std.file, not
  std.process; plugin.mod already uses it the same way.)
- The crt_constructor `hijack()` now returns immediately when
  `currentProcessIsEu4()` is false, before the raw stderr diagnostic
  and before calling hijackProcess(). In a non-EU4 process the DLL
  does nothing at all: no patches, no logger setup, no translation
  mod loading, no exit, and the constructor completes normally.

Placement: the guard sits in the constructor, not at the top of
hijackProcess(), because hijackProcess() has exactly one caller
(hijack(); verified by grep over source/), so guarding the
constructor covers every path into it, and it additionally keeps the
"[DIAGNOSTIC-RAW] crt_constructor entered" stderr write out of
unrelated processes.

Unchanged: inside the eu4 process everything behaves as before,
including the exit(-1) when the EU4 version is unknown.

## Verification

Unit tests: isEu4ExecutablePath is covered in dllmain.d for a full
game path, a bare "eu4", /usr/bin/true, a Steam binary path, an
"eu4.sh" wrapper name, and an empty string. `make test` passes
(11 modules, exit 0). `make all` was run last to restore the normal
build.

Real-machine checks without launching EU4 (EU4 runs were paused to
keep the shared PC's CPU free):

- `LD_PRELOAD=<new .so> /bin/true` -> exit 0, no DIAGNOSTIC-RAW
  output (previously 255).
- `LD_PRELOAD=<new .so> /bin/echo hello-from-echo` -> prints the
  text, exit 0.
- `LD_PRELOAD=<new .so> /bin/false` -> exit 1, i.e. the host
  process's own exit code is preserved.
- No pattern_eu4jps.log was created by these runs, confirming the
  logger setup is skipped outside the game.

Not verified: behaviour inside the real game was NOT exercised on
the machine for this change. It rests on the guard passing straight
through when the executable basename is "eu4" (unit-tested) and on
the EU4-side code being untouched. The owner's next Steam launch
with the rebuilt DLL is the real-machine confirmation.
