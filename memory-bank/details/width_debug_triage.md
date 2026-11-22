# Width measurement diagnostics (EU4DLL_WIDTH_DEBUG)

Recorded 2026-11-22. Branch `work/width-diagnostics`.

## What was added

`EU4DLL_WIDTH_DEBUG=1` (opt-in, same pattern as
`EU4DLL_GLYPH_DEBUG`) enables `[WIDTH-DEBUG]` lines from
`source/plugin/width_debug.d`, called from two existing hooks
in `source/plugin/main_text.d`:

- `bitmap`: per wide glyph fetch in
  `CBitmapFont::GetWidthOfString` (BitmapWidth hook). Fields:
  font, code point, glyph xadvance (glyph+0xC), string pointer,
  byte index, and `acc` = the XMM1 accumulator (sum of
  advance * scale before this glyph; XMM1 is live across this
  fetch, so the hook spills XMM0/XMM1 around the call).
- `rtt`: per wide glyph fetch in the `RenderToTexture`
  measuring / line-break pass (site 1 hook). Fields as above,
  plus `word` / `line` = the float accumulators at 0x4(%rsp)
  and 0x20(%rsp) (verified at VA 0x204ef6a), `limit` = the
  float at 0x2c(%rsp), which the pass compares accumulators
  against with ucomiss at its word-boundary checks
  (VA 0x204edb2 / 0x204f062 / 0x204f137), and `scale` = the
  font scale float at font+0x940.
- `string`: once per measured string (index-0 fetch): byte
  length and the first 48 bytes in hex (escape form).

Latin fetches are not logged. Output is capped at 50,000
lines. With the variable unset the helpers return immediately
and behaviour is unchanged.

## Runs

- `eu4-run/runs/20261122-115500-widthdiag/` — GLYPH_DEBUG +
  WIDTH_DEBUG, country-select screen, shield hovers, zoom.
  720 WIDTH-DEBUG lines.
- `eu4-run/runs/20261122-120015-widthonly/` — WIDTH_DEBUG
  only (see the caveat below). 1,767 WIDTH-DEBUG lines.

## Defect 2 (description overflows its box): mechanism confirmed numerically

The bookmark description texts are measured by the
RenderToTexture pass with limit = 400.00:

- France text (32 chars, all advance 15, scale 1.0): word and
  line accumulators grow 0, 15, ..., 465 (total 480) and
  never reset; the limit is crossed at the 27th char and
  nothing happens.
- Ottoman text (51 chars): line reaches 765 against the same
  limit 400, with exactly one word-boundary event (a space at
  byte index 96, where `word` resets and `line` does not).

The pass only evaluates a break at word boundaries, and a
Japanese sentence is one word, so the measured line simply
outgrows the box. The glyphs themselves measure and draw
correctly (every fetch hit, advance 15 each).

## Defect 3 (hover dialog wraps per character): BitmapWidth itself is clean

In the WIDTH_DEBUG-only run, `GetWidthOfString` on the France
dialog text is measured repeatedly and always cleanly:
acc = 0, 15, ..., 465 (total 480), 15 per char, no misses.
Some calls stop early (acc ends at 225 / 285 / 315 / 330),
consistent with callers passing a length or max-width limit.
So the dialog's per-character wrapping is not caused by the
BitmapWidth measurement returning wrong widths. The dialog's
own wrapping pass (not instrumented here; RenderToScreen
site 1 is the remaining candidate) and how it uses the
measured width are still open, as is the unported tooltip
processing noted in dllmain.d.

## Caveat: EU4DLL_GLYPH_DEBUG corrupts GetWidthOfString measurements

In the combined run, the bitmap `acc` for the France text is
clean (0..345) up to byte index 69 and becomes garbage
(2.72e23, constant) from index 72 on. Index 72 is the first
U+308B (the first GLYPH-DEBUG target code point) in the
string, and the log shows the `[GLYPH-DEBUG] lookup-hit`
line for it immediately before the first garbage line: the
debug formatting inside `wideGlyphLookup` clobbers XMM1,
which is GetWidthOfString's live accumulator across the
fetch site. Consequences:

- Any GLYPH_DEBUG run's BitmapWidth behaviour for strings
  containing U+308B / U+623B / U+2026 is tainted after the
  first such char. The earlier triage observation for
  defect 3 (taken with GLYPH_DEBUG=1) may be partly or
  wholly this artifact and should be re-checked without
  GLYPH_DEBUG.
- The owner's original defect 3 report was made without
  debug flags, so a real defect remains; its mechanism is
  not the BitmapWidth measurement.
- The plain (non-debug) `wideGlyphLookup` does not clobber
  XMM1 in practice: the WIDTH_DEBUG-only run's accumulators
  stay exact across hundreds of wide lookups.
