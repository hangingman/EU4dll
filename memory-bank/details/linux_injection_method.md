# Linux injection method (item 14)

Record of the Linux-ization of the injection method. No injector init
was enabled by this item: `Font.init` / `TextView.init` remain commented
out in dllmain.d. The SetText and ReloadPdxLocalize hooks, which were
already enabled, keep working (verified by smoke, see below).

## Absolute jump in the patcher

- `plugin.patcher.patcher` now provides `makeAbsoluteJmp` (14 bytes:
  `FF 25 00 00 00 00` + 8-byte little-endian target), the form proven by
  the SetText hook, and `makeAbsoluteJmpPadded` (NOP-padded to the exact
  number of overwritten bytes; throws below 14).
- `makeJmp(from, to)` now returns that absolute jump (the `from`
  argument is kept for signature compatibility and is unused).
  The old 5-byte relative form remains as `makeJmpRel`; `makeCall`
  is unchanged (still rel32).
- `PatchManager` gained `addJmpPatch(address, destination, patchLength)`
  and `patchCount()`.
- WARNING recorded in the `makeJmp` doc comment: an absolute-jump patch
  overwrites 14 bytes, so the caller must overwrite only complete
  instructions totalling at least 14 bytes, and any trampoline copying
  the original prefix must copy exactly the patched length.
- The SetText hook now uses the shared `makeAbsoluteJmpPadded`
  (its private copy was removed); its patch is still 17 bytes
  (14-byte jump + 3 NOPs over the copied prefix).

## BytePattern counting

- `findIndexes` now records EVERY hit in each section (new pure helper
  `findAllMatchOffsets`, unit tested including overlapping/masked
  cases). Previously it kept only the first hit per section, so a
  pattern occurring twice in .text reported a count of 1.
- `hasSize(expected, desc)` is no longer a stub returning true: it
  compares against the real count and logs expected/actual on mismatch.
  All existing injectors already gate on `hasSize(1, ...)`, so their
  uniqueness checks are now real.
- `hasAtLeast(expected, desc)` was added for callers that legitimately
  use only the first hit of a multiply-occurring pattern.

## Consequences found by the first full-count smoke run

Making the counts honest broke two already-enabled callers, which were
fixed in this same item:

1. SetText pattern was not unique under full counting. The 22-byte
   prologue occurs twice in the Linux binary: the hooked site
   VA 0x20d9da4 and a second function at VA 0x2140660 that diverges at
   byte 22 (`4D 89 C5`). The pattern was extended with the next
   instructions of the hooked function (`4C 89 44 24 20 48 89 4C 24 30`),
   giving exactly 1 hit at VA 0x20d9da4 - the same site all earlier
   smoke runs hooked as the first hit.
2. PluginVersion version-string detection: `EU4 v1.?? .?` occurs 4
   times (all "EU4 v1.37.5.0 Inca..."). Detection reads only the first
   hit and patches nothing, so its gate was changed from `hasSize(1)`
   to the explicit `hasAtLeast(1)`.
3. ReloadPdxLocalize kept the relative jump deliberately: its original
   trampoline copies exactly 8 bytes and resumes at target+8, so its
   patch must total exactly 8 bytes (5-byte jump + 3 NOPs) and its
   entry trampoline is allocated within rel32 range and checked. It
   now calls `makeJmpRel` explicitly, with the coupling documented in
   the code. An intermediate build that fed it the 14-byte `makeJmp`
   crashed EU4 at startup (exit 11, minidump) - that is how this
   coupling was found. Migrating this hook to the absolute form would
   require extending the copied prefix past the following call
   instruction and fixing up its rel32 target.

Other `makeJmp` callers (font.d, main_text.d, heir_name, input, ...)
sit in inits that dllmain currently leaves disabled; when item 15+
enables any of them, each site must be checked against the 14-byte /
copied-length rule above.

## Existing test updated

`tests/plugin/test_byte_pattern.d` asserted the old first-hit-only
behaviour (pattern `55 48 8D` in the fixture ELF reported 1 result).
Under full counting the fixture yields 41 hits (56 for `55 ?? 8D`),
first still at 88160; the test now asserts those counts and that
`hasSize(41)` passes while `hasSize(1)` fails.

## Verification

- `make test`: 8 modules passed (was 7; the new byte_pattern unittest
  for findAllMatchOffsets was added, and the patcher unittest now pins
  the absolute-jump encoding, a far target outside rel32 range, and
  the NOP padding / rejection below 14 bytes).
- `make all`: OK. `git diff --check`: OK.
- Smoke `runs/20261121-144447` (EU4DLL_SETTEXT_PROBE=1,
  EU4DLL_SETTEXT_REPLACEMENTS="Back=Home"): EU4 alive at menu,
  ended by Exit button, eu4_wait=0, DLL [OK], SetText target=0x20d9da4
  probe installed, mapping id=0 result=applied. The menu screenshot
  shows the normal English main menu (no display corruption).
- Two earlier smoke runs in this item failed and are part of the
  record: runs/20261121-143442 (full counting exposed the non-unique
  SetText pattern and the 4-hit version string; PluginVersion.init
  failed, EU4 exited 255) and runs/20261121-144008 (ReloadTrace fed
  the 14-byte jump; EU4 crashed at startup, eu4_wait=11). Both causes
  were fixed above and the final run passes.
