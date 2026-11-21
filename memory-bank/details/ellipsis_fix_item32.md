# Ellipsis fix: locating the substitution site (item 32, step 1)

Recorded 2026-11-21 (item 32, step 1). Scope: item 31 proved
the Game Browser button's Japanese glyphs resolve in the
measuring passes but only U+2026 reaches the screen. This
step identifies exactly which fetch sites see the Japanese
code points and which site sees the ellipsis, by adding the
caller to the opt-in glyph debug log.

## 1. Instrumentation

- `wideGlyphLookup` (plugin.glyph_table) now logs, under the
  same `EU4DLL_GLYPH_DEBUG=1` opt-in, a `caller=` field: the
  return address inside the calling trampoline, logged as an
  offset from `&wideGlyphLookup` so it can be resolved
  against `nm libeu4dll.so` (each fetch hook has its own
  trampoline symbol). Return address is obtained with the
  `llvm.returnaddress` intrinsic (LDC). Formatter covered by
  a new unittest; `make test` passes (10 modules).

## 2. Run

- Throwaway test mod `testfonts_item32` (all 32 item 23 font
  files, hardlinks, temporary `dlc_load.json`), removed after
  the run, user folder restored.
- `eu4_multiplayer.sh`, `runs/20261121-194451-multiplayer`,
  env `EU4DLL_ENABLE_DECODE=1`, `EU4DLL_GLYPH_DEBUG=1`,
  `EU4DLL_SETTEXT_PROBE=1`, replacement `Back` -> the same
  Japanese word as items 27/30/31. Normal build verified
  first (`make all` run last, .so md5
  5996684bb105afda4f3667f10bdc88de).
- DLL active, SetText id=0 `result=applied`, side table ends
  at 120,880 entries (same as item 31), no crash; the process
  was alive at the Game Browser screen (script ended by
  kill, the known behaviour on that screen). Screenshots
  show the same state as item 31 (button shows only the
  three dots, English UI otherwise normal).

## 3. Caller evidence (render-time lookups, 5 identical groups)

Resolved against `nm libeu4dll.so`
(`wideGlyphLookup` at 0xddab0):

| Logged caller offset | Resolved address | Trampoline | Code points |
|---|---|---|---|
| -0x18923 | 0xc518d | mainTextProc4V137GetRequired_hook (CBitmapFont::GetRequiredSize, first fetch) | U+623B, U+308B |
| -0x18536 | 0xc557a | mainTextRenderToTextureV137Site1_hook (RenderToTexture measuring / line-break pass) | U+623B, U+308B |
| -0x18434 | 0xc567c | mainTextRenderToTextureV137Site2_hook (RenderToTexture draw pass) | U+2026 only |

So per group: the string is measured twice with both
Japanese glyphs resolving (GetRequiredSize, then
RenderToTexture's own measuring pass), and the draw pass of
the same RenderToTexture call fetches exactly one glyph,
U+2026. No other fetch site sees these code points at
render time.

## 4. What this rules in and out

- The measuring side is correct end to end: GetRequiredSize
  (the GUI text-sizing entry, which pre-measures the global
  `" ..."` string at VA 0x271246c for its truncation logic)
  does NOT truncate this string at the measuring fetch - both
  glyphs are fetched there and, separately, in
  RenderToTexture's measuring pass.
- The substitution happens inside CBitmapFont::
  RenderToTexture, between its measuring / line-break pass
  (fetch VA 0x204ef59) and its draw pass (fetch VA
  0x2051088): the draw pass iterates a string that already
  decodes to a single U+2026. RenderToTexture contains no
  0x2026 immediate, so the ellipsis is in the data the draw
  pass reads (the per-line buffer built by the measuring /
  line-break pass), not a constant in the draw code.
- Working hypothesis for step 2: the line-breaking pass
  builds its line buffer byte-wise (or checks the decoded
  width against the target texture width using a different,
  byte-based width), decides the line does not fit, and
  stores an ellipsis-only line for the draw pass.

## 5. Next (item 32, step 2)

Disassemble RenderToTexture between the two fetch sites
(VA 0x204e886-0x20519f8, about 3,000 instructions) and find
where the line buffer for the draw pass is built and where
the fit check fails for escaped text; or instrument the
RenderToTexture site hooks to log the raw bytes at the char
pointer when U+2026 is produced, to see the exact buffer
the draw pass reads. Then fix that width/copy logic, keep
`EU4DLL_GLYPH_DEBUG` until the fix is verified, and re-run
this same Game Browser check.
