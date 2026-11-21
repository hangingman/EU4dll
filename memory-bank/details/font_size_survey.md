# Font size survey: generated fonts look 2-3 pt too big

Recorded 2026-11-21. Scope: read-only survey for the owner's
report (2026-11-21, after the generated fonts went live on the
owner's machine) that the generated Japanese fonts look about
2-3 pt too large overall. No code changed, no game launch; this
file only prepares the size-adjustment task that follows.

Sources read: `memory-bank/details/charset_and_font_generation.md`
(item 22), `memory-bank/details/font_generation_item23.md`
(item 23), the generator `~/work/eu4-run/item23_gen.py`, the
generated `.fnt` files in `~/work/eu4-run/item23/gfx/fonts/`
(16 `.fnt` + 16 `.tga`; the task brief said .dds, the actual
textures are TGA), and the vanilla `.fnt` files in the game
folder `gfx/fonts/`.

## 1. How the generated fonts got their size

Generator: `~/work/eu4-run/item23_gen.py` (Python, Pillow +
fontTools, kept outside the repo). Per font it:

- reads the vanilla `.fnt` `info size` and `bold` and rasterises
  Noto Sans CJK JP (Regular or Bold TTC, face 0) at exactly that
  pixel size with `ImageFont.truetype(path, size)`;
- writes `info size` back unchanged (nominal size == vanilla);
- DISCARDS the vanilla `lineHeight` / `base` and replaces them
  with the source font's own metrics at that size:
  `lineHeight = ascent + descent`, `base = ascent`
  (item 22/23 decision: the vanilla Garamond values are too
  small for Noto's em box and produced negative yoffsets);
- takes each glyph's ink box from Pillow `textbbox` and
  `xadvance` from `textlength`, i.e. all per-glyph metrics are
  Noto's at the nominal size.

So nothing in the pipeline scales the glyphs up on purpose; the
nominal size is the vanilla size everywhere. The oversize the
owner sees comes from the design metrics of the source font,
quantified next.

## 2. Measured differences vs vanilla

`common` values, all 16 fonts (gen / vanilla):

| font | size | lineHeight | base |
|---|---|---|---|
| Arial12 | 14 | 22/14 | 17/11 |
| garamond_12 | 12 | 18/12 | 14/9 |
| garamond_14 (+bold) | 14 | 22/14 | 17/11 |
| garamond_16 (+bold) | 16 | 24/16 | 19/12 |
| garamond_24 | 24 | 35/24 | 28/18 |
| standard / standard_18 / vic_18 / vic_18_grey | 18 | 27/18 | 21/13 |
| standard_22 / vic_22 / vic_22_bl | 22 | 33/22 | 26/16 |
| vic_29 | 29 | 43/29 | 34/21 |
| vic_36 | 36 | 53/36 | 42/26 |

lineHeight is 1.47-1.57x vanilla and base 1.50-1.62x vanilla at
every size, because both now come from Noto's em box.

Per-glyph comparison over the 215 printable Latin ids shared
with vanilla (means):

| font | xadvance gen/van | width gen/van | height gen/van |
|---|---|---|---|
| vic_18 (= standard) | 11.58/7.13 (1.62x) | 11.76/7.07 (1.66x) | 14.95/9.05 (1.65x) |
| vic_36 | 21.90/13.89 (1.58x) | 22.00/12.56 (1.75x) | 28.74/17.50 (1.64x) |

Spot checks at 18 px: `A` ink height 14 vs vanilla 10, `a`
10 vs 6, `0` 14 vs 9; `A` xadvance 12 vs 9. CJK glyphs have no
vanilla counterpart; in the generated fonts they fill the em:
at size 18 the 3,011 CJK glyphs average width 17.96, height
18.00, xadvance 17.96 (U+623B: 18x17, xadvance 18). At size 36:
35.92 / 34.28 / 35.92.

Interpretation of "2-3 pt too big":

- The nominal size is identical, so the difference is not a
  wrong size value anywhere. It is (i) CJK glyphs occupying
  ~100% of the em where the vanilla Latin design's cap height
  is ~55% of nominal (10/18) and x-height ~33% (6/18), and
  (ii) even the Latin glyphs rendering ~1.6x larger in ink and
  advance than the Garamond originals, plus (iii) lines spaced
  1.5x taller via lineHeight.
- Matching vanilla Latin ink height exactly would need a
  raster size near 18/1.65 = 11 px for vic_18, which would
  shrink kanji to 11 px - far more than the owner asked for.
  The owner's "2-3 pt" is a judgement of the overall screen
  impression, and it is the amount to apply: it maps to a
  raster-size reduction of 2-3 px per font (18 -> 16 or 15),
  NOT to metric equality with Garamond.

## 3. Adjustment options

How the game consumes a BMFont text font (the semantics every
earlier item relied on): `char x/y/width/height` is both the
source rectangle in the atlas and the on-screen quad size,
`xoffset/yoffset` place the quad against the pen and baseline,
`xadvance` advances the pen, `lineHeight` is the line step and
`base` the baseline position inside the line.

(a) Regenerate at a smaller raster size (size - 2 or - 3).
Every metric - glyph ink, xadvance, lineHeight, base, yoffset -
derives from the rasterised font, so all of them scale together
by (size-delta)/size and stay mutually consistent. At 18 px,
delta 2 gives kanji ink 16 px, lineHeight 24, `A` height ~12.4;
delta 3 gives 15 px, 22.5, ~11.7 (vanilla 10). Atlases shrink
too, so the texture-cap situation only improves. Cost: rerun
the existing generator with one parameter changed; small fonts
suffer most in relative terms (garamond_12 at delta 3 is 9 px,
where kanji legibility gets marginal).

(b) Scale the .fnt metrics only, keep the atlas images.
NOT viable in the full form: width/height are also the atlas
source rectangle, so scaling them down crops each glyph's
strokes (top-left of the ink box) instead of shrinking the
glyph. Scaling only the spacing fields (xadvance, lineHeight,
base, offsets) keeps glyph size untouched - the very thing the
owner wants smaller - and breaks the yoffset = base + ink-top
relation the generator established, risking baseline drift and
line overlap. (Caveat: that EU4 uses width/height as both
source rect and quad size is the BMFont format semantics all
previous items assumed; it was not re-verified by disassembly
in this survey.)

(c) Other routes considered:
- Clamp lineHeight/base back toward vanilla while keeping the
  glyphs: fixes only the line spacing, not glyph size, and
  re-opens the negative-yoffset problem item 23 avoided by
  taking Noto's metrics.
- A different source font: Noto's em-filling CJK design is the
  cause, and any full-coverage CJK font behaves similarly;
  switching fonts does not give a 2-3 pt change.
- DLL-side scaling: out of scope and unrelated - the existing
  FontSizeLimit injector only raises the texture file-size cap
  (item 18/23), it does not scale glyphs.

## 4. Recommendation for the implementation task

Option (a): regenerate with a uniform point delta.

- Change in `~/work/eu4-run/item23_gen.py`, in `gen()`:
  `size = int(info["size"])` becomes
  `size = max(9, int(info["size"]) - DELTA)` with DELTA taken
  from argv or an environment variable; everything downstream
  (rasterisation, getmetrics, textbbox, textlength, the written
  `info size`) already follows the `size` variable. No other
  generator change is needed. Generate two sets, DELTA=2 and
  DELTA=3, into separate output folders for A/B comparison.
- Expected headline numbers for vic_18: DELTA=2 -> size 16,
  lineHeight 24, base ~19, kanji 16 px; DELTA=3 -> size 15,
  lineHeight 22-23, base ~17-18, kanji 15 px.
- One open question the first A/B run must answer: the written
  `info size` becomes the reduced size (15/16 instead of 18).
  `info size` is informational in BMFont and no earlier item
  saw the game use it, but if anything behaves oddly, the
  fallback is to write the vanilla size in `info` while
  rasterising at the reduced size.
- Verification (owner's machine, same screens as the current
  live check): main menu (vic_18; check that labels truncated
  with an ellipsis in the current build, e.g. the Single
  Player button, fit better), Game Browser (the established
  check screen), country select (multi-line scenario
  description: check line spacing and that no kana/kanji rows
  clip or overlap at the smaller lineHeight), and an in-game
  panel with dense small text (Arial12 / garamond sizes are
  where DELTA=3 may go too far). Compare DELTA=2 and DELTA=3
  screenshots of the same screens; the owner picks.
- Rollback is trivial: the current 32 files stay untouched in
  `~/work/eu4-run/item23/gfx/fonts/`; the adjusted sets are
  separate folders copied into the mod the same way.

## 5. Unknowns

- Whether the game reads `info size` for anything (see above);
  only an A/B launch can settle it.
- EU4's quad/source-rect use of width/height was assumed from
  BMFont semantics, not re-verified against the binary here.
- No screen was re-measured in this survey (no launch, per the
  task): the claim "lineHeight 1.5x is part of the perceived
  oversize" is inference from metrics, not from pixel
  measurements of live screens. The A/B screenshots in the
  implementation task will show how much of the impression is
  glyph size vs line spacing.


## 6. A/B sets generated (2026-11-21, implementation follow-up)

Option (a) was carried out the same day. The original generator
and the live set in `~/work/eu4-run/item23/` are untouched.

- Generator copy: `~/work/eu4-run/font_size_gen.py` - identical
  to `item23_gen.py` except `OUTDIR` comes from the environment
  variable `EU4DLL_FONT_OUTDIR`, `DELTA` from `EU4DLL_FONT_DELTA`,
  and `gen()` uses `size = max(9, int(info["size"]) - DELTA)`.
  Nothing else changed.
- Sets produced (16 `.fnt` + 16 `.tga` = 32 files each):
  - DELTA=2: `~/work/eu4-run/font-size-test/delta2/gfx/fonts/`
  - DELTA=3: `~/work/eu4-run/font-size-test/delta3/gfx/fonts/`

Verification (numeric, `.fnt` parsing; no game launch):

- File counts: 32 per set. Glyph counts and glyph id sets match
  the original set exactly for all 16 fonts in both sets
  (vic_18: 3,240 glyphs in all three sets).
- `info size` reduced by exactly DELTA for every font (floor 9
  never reached; smallest result is garamond_12 at DELTA=3 -> 9).
  Full table (orig -> delta2 / delta3, lineHeight likewise):
  Arial12 14->12/11 (22->18/17), garamond_12 12->10/9 (18->15/14),
  garamond_14(+bold) 14->12/11 (22->18/17),
  garamond_16(+bold) 16->14/13 (24->22/20),
  garamond_24 24->22/21 (35->33/32),
  standard/standard_18/vic_18/vic_18_grey 18->16/15 (27->24/23),
  standard_22/vic_22/vic_22_bl 22->20/19 (33->30/29),
  vic_29 29->27/26 (43->40/39), vic_36 36->34/33 (53->50/49).
- vic_18 detail (CJK = ids >= U+3000 with ink, n=3,013 in all
  sets; mean width / height / xadvance):
  - orig: size 18, lineHeight 27, base 21; 17.95 / 17.99 / 17.96
  - DELTA=2: size 16, lineHeight 24, base 19; 15.96 / 16.34 /
    15.96. Ratios vs orig: lineHeight 0.889, width 0.889,
    xadvance 0.889 (all = 16/18), ink height 0.908 (rounding).
  - DELTA=3: size 15, lineHeight 23, base 18; 14.96 / 15.68 /
    14.96. Ratios: width and xadvance 0.833 (= 15/18), lineHeight
    0.852 (23 instead of the ideal 22.5 - ascent+descent rounding
    at 15 px; the survey predicted 22-23), ink height 0.872.

Next step is the owner's A/B screen comparison from section 4:
copy one set over the mod's `gfx/fonts`, launch, compare the
same screens, then the other set. The `info size` open question
in section 4 still stands for that first launch.
