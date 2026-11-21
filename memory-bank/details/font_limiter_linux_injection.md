# Font limiter injection for Linux v1.37.5 (item 17)

Recorded 2026-11-21 (item 17). Scope: implement only the
charCodePointLimiter patch, the one Font injector whose Linux
pattern was uniquely derived in item 12. The other Font
injectors (BufferClear, Expansion, FontSizeLimit, HeapZeroClear)
are item 18 and are unchanged; they still return version /
unmatched errors on v1.37.5, so the opt-in decode log still
reports injector errors overall. That is expected and non-fatal
(item 15 wiring).

## Implementation

- `source/plugin/font.d`, `charCodePointLimiterPatchInjector`:
  new `EU4Ver.v1_37_5` case.
- Pattern (item 12, VA 0x204e366 in
  `CBitmapFont::ParseFontFile`):
  `41 81 FD FF 00 00 00 0F 87 25 01 00 00`
  (`cmp r13d, 0FFh` / `ja +0x125`).
- Gate: `hasSize(1, "Char Code Point Limiter")` (item 14 real
  counting). When the count is not exactly 1, nothing is patched
  and `unmatchdCharCodePointLimiterPatchInjector` is set.
- Patch semantics, mirroring the Windows v1.33 case: the
  immediate `FF 00 00 00` starts at pattern offset 3, so writing
  `0xFF` at offset 4 (address + 4) changes it to `FF FF 00 00`,
  i.e. the limit widens from 0xFF to 0xFFFF. (The Windows site
  writes at +3 because its instruction has no REX prefix; the
  Linux site has the `41` prefix, hence +4.)
- Runs only through the existing opt-in: `Font.init` is called
  only when `EU4DLL_ENABLE_DECODE=1` (item 15). Without the
  variable, behaviour is unchanged.

## Verification

- `make test`: 9 modules passed. `make all`: OK.
  `git diff --check`: OK.
- Smoke `runs/20261121-150649` with
  `EU4DLL_ENABLE_DECODE=1 EU4DLL_SETTEXT_PROBE=1
  EU4DLL_SETTEXT_REPLACEMENTS="Back=Home"`:
  - `eu4_stdout.log` contains
    `WriteMemory for charCodePointLimiterPatchInjector (v1.37.5) called.`
    and no Char Code Point Limiter match-count mismatch was
    logged, so the pattern hit exactly once and the patch was
    applied.
  - SetText mapping id=0 result=applied, `DLL [OK]` once,
    EU4 reached the menu and ended by the Exit button
    (eu4_wait=0).
  - The menu screenshot (shot_menu.png in that run) was checked
    visually: normal English main menu (Single Player /
    Multiplayer / Tutorial / Credits / Options / Exit,
    "EU4 v1.37.5.0 Inca"), no display corruption.

## What remains

- Item 18: BufferClear / Expansion candidates and the
  FontSizeLimit re-search.
- The limiter alone does not enable Japanese display: the
  TextView fetch-site hooks (item 19) and the escape-codec
  wiring (item 20) are still required.
