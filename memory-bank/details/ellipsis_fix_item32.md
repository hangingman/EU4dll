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

## 6. Step 2 (2026-11-21): the draw-pass buffer holds only the lead bytes

Instrumentation: the RenderToTexture site 1 and site 2 wide
paths now call `wideGlyphRawLog` (plugin.glyph_table, same
`EU4DLL_GLYPH_DEBUG=1` opt-in) before the glyph lookup. It
reconstructs the string start as charPtr - (loop index at the
escape start) and dumps up to 48 bytes as hex, so the exact
buffer each pass reads can be compared. The naked hooks save
RAX/RCX/R10/R11 around the call (four pushes, stack alignment
preserved) because the logger is a D function and clobbers
caller-saved registers; the formatter is unit-tested and
`make test` passes (10 modules).

Run: throwaway test mod `testfonts_item32s2` (all 32 item 23
font files, hardlinks, temporary `dlc_load.json`), removed
after the run, user folder restored. `eu4_multiplayer.sh`,
`runs/20261121-195701-multiplayer`, env
`EU4DLL_ENABLE_DECODE=1` + `EU4DLL_GLYPH_DEBUG=1` + SetText
probe, same Japanese Back replacement. Normal build verified
first (`make all` run last, .so md5
37484c609b1d90de8b75642811d25b16). SetText id=0 applied, no
crash, process alive at the Game Browser screen (ended by
kill, known behaviour); screenshot checked visually - button
again shows only the three dots, English UI otherwise normal.

Evidence (5 identical render groups each):

| Pass | Raw bytes at the fetch | Decodes to |
|---|---|---|
| Site 1 (measuring), index 0 | `11 49 62 10 8b 30` | U+623B, U+308B (the full escaped string) |
| Site 1 (measuring), index 3 | `11 49 62 10 8b 30` | U+308B |
| Site 2 (draw), index 0 | `11 10` (then NUL) | see below |

So the draw pass does NOT read the original string and does
NOT read a ` ...` ASCII ellipsis either. Its line buffer is
2 bytes long: `0x11 0x10` - exactly the LEAD byte of each of
the two escape sequences (`11 49 62` and `10 8b 30`), with
the two payload bytes of each sequence dropped. Whoever
builds this buffer between the measuring pass and the draw
pass copies one byte per character (per escape sequence),
i.e. it walks the string with the decoded character step
(3 bytes, matching the hooks' index advance) but copies only
the single byte at each character position.

Why that draws exactly one U+2026: at site 2 the first byte
`0x11` is ESCAPE_SEQ_2, so the hook reads the word at +1,
which is `0x10` followed by the buffer's terminating NUL,
i.e. word `0x0010`; `0x0010 - SHIFT_2 (0x0E) = 0x0002`, which
lies in the NO_FONT band, so the hook maps it to NOT_DEF
(U+2026) and the wide lookup returns the real ellipsis
glyph. The loop index then advances by 3, past the 2-byte
buffer, so exactly one glyph - the ellipsis - is drawn. This
fully explains the item 30/31 observations (three dots on
screen are the single U+2026 glyph of the generated font).

## 7. Next (item 32, step 3)

Find the per-character 1-byte copy that builds the
RenderToTexture line buffer between the site 1 measuring
loop (fetch VA 0x204ef59) and the draw loop (fetch VA
0x2051088): the disassembly region 0x204f000-0x2051000
contains several `CString(char)` append blocks (e.g. around
VA 0x204ea19-0x204ec99 in the function's first phase and the
line-store blocks after the measuring loop). The fix must
make that copy move all 3 bytes of an escape sequence (or
make the buffer hold the decoded text), then re-run this
same Game Browser check. `EU4DLL_GLYPH_DEBUG` (now including
the raw dump) stays until item 32 closes.
