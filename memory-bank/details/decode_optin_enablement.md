# Decode enablement wiring (opt-in) for Linux v1.37.5

Recorded 2026-11-21 (item 15). Scope: wire `Font.init` and
`TextView.init` into `dllmain.d` behind an explicit opt-in and
verify on the real machine that normal English display and
shutdown are unaffected. This item does NOT make decoding
functional on Linux: items 12/13 derived AOB patterns only, and
the Linux fetch-site hooks themselves (decode where the byte is
fetched, glyph table +0x100, scale +0x940, loop 1 split over
three functions) are not written yet. Item 16 (on-screen
Japanese check) therefore still has its prerequisite unmet for
actual decoded rendering; what this item proves is the wiring,
the failure reporting, and that the opt-in path is safe.

## Wiring

- `hijackProcess` in `source/plugin/dllmain.d` now calls
  `Font.init(eu4Version)` then `TextView.init(eu4Version)`
  (upstream order) only when the environment variable
  `EU4DLL_ENABLE_DECODE` is exactly "1" (pure helper
  `decodeOptInEnabled`, unit tested). Otherwise it logs that the
  decode inits are skipped and behaviour is unchanged.
- The returned `DllError` is aggregated into `success` and, if
  any flag is set (`dllErrorHasAny`, unit tested), logged as an
  error: "Decode init reported injector errors; no decode patch
  is active for the failed injectors. Continuing startup."
  It is deliberately NOT fatal: the PluginVersion gate remains
  the only exit(-1) gate. On v1.37.5 every font/main_text
  injector except HeapZeroClear falls into its `default` case
  (version error; HeapZeroClear reports unmatched), so the
  opt-in currently applies no patch at all - which the smoke
  run below confirms is safe.

## Bug found by the first opt-in smoke run: DllError `|`

- `DllError.opBinary("|")` in `source/plugin/input/package.d`
  was `return this | rhs;` - infinite self-recursion. It had
  never run before because no enabled code path aggregated a
  `DllError` (Font.init / TextView.init were commented out).
- First opt-in smoke `runs/20261121-145211`: EU4 died before
  the menu (eu4_wait=139, SIGSEGV) immediately after the
  "EU4DLL_ENABLE_DECODE=1; calling Font.init" log line, with
  `DLL [OK]` count 0. Cause: stack overflow in the first
  `result | injector(...)` aggregation inside Font.init.
- Fix: `opBinary("|")` now ORs field by field over `tupleof`,
  with a unittest pinning the aggregation (empty|empty stays
  empty, flags from both sides are kept, unrelated flags stay
  clear). `make test` went from 8 to 9 modules passed.

## Verification

- `make test`: 9 modules passed. `make all`: OK.
  `git diff --check`: OK.
- Smoke `runs/20261121-145625` with
  `EU4DLL_ENABLE_DECODE=1 EU4DLL_SETTEXT_PROBE=1
  EU4DLL_SETTEXT_REPLACEMENTS="Back=Home"`: EU4 alive at menu,
  ended by Exit button, eu4_wait=0, `DLL [OK]` logged once,
  log shows the opt-in line followed by the decode-error line
  above (expected on v1.37.5) and startup continued.
  The menu screenshot (shot_menu.png in that run) was checked
  visually: normal English main menu (Single Player /
  Multiplayer / Tutorial / Credits / Options / Exit,
  "EU4 v1.37.5.0 Inca"), no display corruption.
- Failed run kept in the record: `runs/20261121-145211`
  (DllError `|` recursion, see above).

## What remains for real decode enablement

Write the Linux hooks at the fetch sites derived in items
12/13 (Font limiter patch semantics; Proc1 two sites in
FillVertexBuffer; Proc4 one site in each loop-1 function;
Proc2 and the s_lastCodePoint hand-off have no Linux anchor),
add `EU4Ver.v1_37_5` cases for them, and only then will the
opt-in log "Decode init [OK]" and item 16 become meaningful.
