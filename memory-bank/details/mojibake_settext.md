# Mojibake of Japanese SetText replacements: cause isolation

Recorded 2026-11-21 (item 5). Question: why does a Japanese replacement
such as `Back=戻る` garble on screen even though the SetText replacement
itself succeeds? This document isolates the cause from code and one
real-machine run. No implementation was changed.

## Conclusion

1. The SetText replacement does **not** pass through any character
   conversion. The hook writes the replacement bytes from the
   environment variable verbatim into the CString buffer.
2. The DLL's double-byte mechanism is a *decode-side* escape scheme in
   the game's text-processing loop, and on Linux it is not enabled yet:
   the relevant hooks exist in source but are commented out in
   `dllmain.d`.
3. EU4 therefore reads the replaced CString as ordinary single-byte
   text. The UTF-8 bytes of a Japanese string are fetched one byte at a
   time and each byte is mapped to an unrelated single-byte glyph, so
   the string displays as mojibake. Length and capacity are not the
   problem: the replacement is applied successfully.

## Evidence from code

### The SetText path performs no conversion

- `source/plugin/localization/settext_hook.d`:
  `parseSetTextProbeEntry` stores the source and replacement as raw
  byte arrays taken from `EU4DLL_SETTEXT_REPLACEMENTS`, and
  `tryReplace` writes those bytes plus a terminating NUL into the
  CString data buffer with `process_vm_writev`, then updates the
  length field (+8). No encoding conversion function is called
  anywhere on this path, and `translationMap` is never consulted.
- `source/plugin/mod.d`: `loadTranslationMods()` parses the mod yml
  files and stores the values in `translationMap` as UTF-8 D strings,
  again with no conversion to any game-internal encoding. The map is
  currently only used for load-time observation logs.

### The double-byte mechanism lives in the text loop, and is off

- `source/plugin/main_text.d` defines the decode side of the scheme:
  `ESCAPE_SEQ_1..4` are the bytes 0x10-0x13. In `mainTextProc1_hook`,
  a non-escape byte is fetched as a single byte
  (`movzx EAX, byte ptr [RAX + RBX]`) and used as a glyph-table index;
  an escape byte makes the hook read the following two bytes as one
  code point, adjusted by `SHIFT_2`/`SHIFT_3`/`SHIFT_4`, and look that
  code point up in the same table (values above `NO_FONT` become
  `NOT_DEF`). Japanese characters are representable only in this
  escaped form, paired with the font-side patches in
  `source/plugin/font.d` (for example "Char Code Point Limiter").
- `source/plugin/dllmain.d` (`hijackProcess`): the only active pieces
  are `loadTranslationMods()`, `ReloadTrace`, `SetTextHook`, and
  `PluginVersion`. `Font.init` and `TextView.init` (main_text) are
  commented out as TODO, as are the input, tooltip/button, map, and
  localisation entry hooks. So on Linux v1.37.5 today, neither the
  escape decode nor the font expansion ever runs.

### What EU4 does with the replaced bytes

Because the decode hooks are off, the game treats the CString as
single-byte (Windows-1252-family) text: one byte is one character.
`戻る` in UTF-8 is the six bytes E6 88 BB E3 82 8B. Read as single-byte
text those are six separate characters (æ, a control/ˆ, », ã, ‚, ‹ in
Latin-1 terms), none of them a Japanese glyph. That is exactly the
garbling the owner observed. The same applies to any multibyte UTF-8
replacement, regardless of the capacity check passing.

## Evidence from the real machine

Run `~/work/eu4-run/runs/20261121-123828` (eu4_smoke.sh, Xvfb,
`EU4DLL_SETTEXT_PROBE=1`, `EU4DLL_SETTEXT_REPLACEMENTS='Back=戻る'`):

- DLL log: `SetText mapping id=0 length=4 result=loaded` (source
  `Back`, 4 bytes; the replacement `戻る` is 6 UTF-8 bytes).
- stderr raw diagnostics: `SetText capacity id=0 length=4 capacity=15`,
  then `SetText replacement applied` and
  `SetText mapping id=0 length=4 result=applied reason=none`.
- EU4 exited normally via the Exit button (`eu4_wait=0`).

So the write side works end to end for Japanese bytes; only the
interpretation on the display side is missing. Per the item's scope,
the on-screen result was not used as a criterion.

## Outlook (not implemented)

- Replacing at SetText with raw UTF-8 can never display Japanese, no
  matter how the length/capacity handling improves. Two ingredients
  are missing, in this order:
  1. The decode side: port and enable the `main_text.d` text-loop
     hooks and the `font.d` patches for Linux v1.37.5 (TODO.txt
     already lists the Ghidra exploration of "text processing loop 2"
     as on hold).
  2. The encode side: replacement text must be supplied in the
     escaped form (0x10-0x13 plus a two-byte shifted code point per
     character) that those hooks decode, not in UTF-8. This repo
     currently contains no UTF-8-to-escape encoder.
- An alternative injection point is the localisation load path, where
  UTF-8 yml text becomes game-internal text; `ReloadPdxLocalize` was
  already ruled out as a display-update point (it rebuilds the
  dictionary without refreshing generated UI), so the conversion
  point inside the initial load would have to be identified first.
- Until the decode side exists, SetText replacement work should stay
  with ASCII/English test strings, which is how items 1-4 were
  verified.
