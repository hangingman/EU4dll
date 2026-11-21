# Ellipsis display: distinguishing the cause (item 31)

Recorded 2026-11-21 (item 31). Scope: item 30 left two
candidate explanations for the Game Browser button showing
only an ellipsis-like three dots instead of the Japanese
replacement text: (1) a GUI-side measuring/truncation step
substitutes an ellipsis before the hooked render paths, or
(2) the side-table lookup misses for this button's font
instance and the NOT_DEF glyph (U+2026) is drawn.

## 1. Instrumentation

Opt-in debug logging was added to the side-table wrappers in
`source/plugin/glyph_table.d`, gated by the environment
variable `EU4DLL_GLYPH_DEBUG=1` (off by default, raw fd-2
writes, in the style of the SetText probe diagnostics):

- `wideGlyphRegister` logs `register-hit` /
  `register-rejected` and `wideGlyphLookup` logs
  `lookup-hit` / `lookup-miss`, each line carrying the font
  base, the code point, the glyph pointer and the table size.
- Only three code points are logged, the ones that decide
  this item: U+623B and U+308B (the two glyphs of the button
  replacement text) and U+2026 (the ellipsis). Font loading
  registers tens of thousands of wide glyphs, so logging all
  of them would flood the output; the three-point filter
  keeps the log at 265 lines for a full run.
- Because every decode path (the five TextView fetch sites,
  all eight byte-width BitmapFont sites and the ParseFontFile
  duplicate check) resolves wide glyphs through
  `wideGlyphLookup`, this single point observes all of them.
- The formatter and the code-point filter are covered by a
  new unittest; `make test` passes (10 modules).

## 2. Run

- Throwaway test mod `testfonts_item31` (all 32 item 23 font
  files, hardlinks, temporary `dlc_load.json`), removed after
  the run, user folder restored.
- `eu4_multiplayer.sh`, `runs/20261121-193152-multiplayer`,
  env `EU4DLL_ENABLE_DECODE=1`, `EU4DLL_GLYPH_DEBUG=1`,
  `EU4DLL_SETTEXT_PROBE=1`, replacement `Back` -> the same
  Japanese word as items 27/30. Normal build verified first
  (`make all` run last, .so md5 5a4bae88b4c1cbfc189afa3c8e2b5091).
- DLL active, SetText id=0 `result=applied`, Duplicate
  character ID = 0, Invalid character ID = 0, no crash; the
  process was alive at the Game Browser screen (script ended
  by kill, the known behaviour on that screen).
- Visual: `shot_multiplayer.png` checked visually - the main
  UI renders normally in the generated fonts, and the
  bottom-left button again shows only the three dots, the
  same state as item 30.

## 3. Log evidence

- Registration: all three code points registered with
  `register-hit` for 40 font instances each (20 generated
  fonts parsed twice), no `register-rejected` line. The
  side table ends the run with 120,880 entries.
- Load-time lookups: exactly one `lookup-miss` per code point
  per font instance, each immediately before its
  registration (the ParseFontFile duplicate check working as
  designed). No other misses occur.
- Render-time lookups: after loading, the only lookups are
  25 `lookup-hit` lines, all on one font instance
  (0xfdde650), in five identical groups of
  U+623B, U+308B, U+623B, U+308B, U+2026 - 10 hits for each
  Japanese code point and 5 hits for U+2026, every one
  returning a real glyph pointer. There is no render-time
  miss for either Japanese code point on any font.

## 4. Conclusion: explanation 1 holds, explanation 2 is out

- Explanation 2 (side-table lookup miss for the button's
  font instance, NOT_DEF drawn instead) is RULED OUT: the
  decode reaches the hooked paths, both Japanese code
  points resolve to real glyphs on the very font instance
  used at render time, every time they are asked for.
- Explanation 1 holds in substance: the glyphs are fetched
  (twice per group, consistent with measuring passes over
  the two-glyph string), yet the only glyph that reaches
  the screen is U+2026 - the GUI control itself decides the
  text does not fit and draws an ellipsis instead. The
  repeated fetch pattern (the string measured twice, then
  only the ellipsis glyph drawn) matches a truncation
  decision inside the GUI button code, upstream of the draw
  pass. The measuring step that overestimates the width is
  not one of the hooked BitmapFont sites as used here, or
  it measures the raw escaped byte string (6 bytes) instead
  of the decoded glyphs; locating that exact site is the
  remaining work for item 32.
- Supporting observation: the same Game Browser screen
  ellipsises ordinary long English labels too (a column
  header shows `Pas ...` and a checkbox label is cut with
  an ellipsis), so ellipsising is this GUI layer's normal
  behaviour when its width check fails.

## 5. Next (item 32)

Find the GUI-side width check / truncation site for button
text (the caller side of the BitmapFont measuring calls for
this control), fix the width it computes for escaped text,
and re-run this same check: the button must show the two
Japanese glyphs. The `EU4DLL_GLYPH_DEBUG` logging stays in
place (opt-in, off by default) until item 32 closes, then
it can be removed.
