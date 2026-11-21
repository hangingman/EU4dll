# Font generation and placement (item 23)

Recorded 2026-11-21 (item 23). Scope: generate the Japanese font
set with the method decided in item 22
(`memory-bank/details/charset_and_font_generation.md`) and place
it under the translation mod's `gfx/fonts`, then smoke-check that
normal English rendering is not broken.

## 1. What was generated

Generator: `~/work/eu4-run/item23_gen.py` (kept outside the repo,
like the item 22 collection scripts). Pillow + fontTools, source
font Noto Sans CJK JP (Regular TTC for non-bold fonts, Bold TTC
for the fonts whose vanilla `info` line has `bold=1`), face
index 0. Output per font: a text `.fnt` in vanilla form
(info / common / char lines, no page/chars lines, no kernings)
plus an RGBA TGA atlas (white glyphs on transparent background;
`vic_18_grey` uses RGB 166 and `vic_22_bl` RGB 0, matching the
tints measured in the vanilla textures).

Fonts generated (16): the UI text fonts actually referenced by
`interface/` (usage counts measured in this item: vic_18 2724,
vic_22 418, vic_18_grey 79, Arial12 47, standard 32, vic_29 29,
standard_18 12, vic_36 11, garamond_14/14_bold 8, garamond_16_bold
6, garamond_16 3, standard_22 2, vic_22_bl 1, plus vic_18's
siblings standard/garamond_12/garamond_24 for completeness).
Not generated, with reasons: Mapfont (map names, size 100, DDS),
tahoma_60 / tahoma_20_bold (title/large display), and the shadow
variants vic_18s / vic_22s / vic_29s / vic_36s (separate shadow
rendering with padding 3; follow-up if a screen shows them
untranslated).

Glyph set per font: the 3,135 font ids from item 22 (3,130
charset ids, with the 5 CP1252 specials registered at BOTH the
byte id and the Unicode code point) UNION that font's own
vanilla id set, i.e. 3,218-3,240 glyphs per font. U+2007 /
U+200B / U+FE0E are registered as empty zero-width glyphs, as
decided in item 22. Atlas sizes run 1024x1024 to 2048x4096;
total output is 154 MiB in `~/work/eu4-run/item23/gfx/fonts/`.

Metrics decision: `size` is the vanilla size, but
`lineHeight` / `base` come from the source font's own metrics at
that size (the item 22 PoC precedent: Noto at 18 px gives
lineHeight 27, base 21), NOT from the vanilla Garamond values
(18 / 13), which are too small for Noto's em box and produced
negative yoffsets in a first trial. Consequence: Latin advances
are wider than Garamond's (e.g. `A` xadvance 12 vs vanilla 9 at
18 px) and line spacing grows; whether that is acceptable on
real screens is for the item 24 visual check to judge.

## 2. Placement: not possible from agent, files left in ~/work

The translation mod folder
`~/.local/share/Paradox Interactive/Europa
Universalis IV/mod/eu4dll_translations/` is readable by agent
(it contains only `localisation/`) but NOT writable
(`os.access(..., W_OK)` is False, and there is no `gfx/`
subfolder yet). Per the item 23 fallback rule, the generated
files stay at `~/work/eu4-run/item23/gfx/fonts/` on the home PC and
placement is left to the owner:

1. Create `gfx/fonts/` inside the `eu4dll_translations` mod
   folder.
2. Copy all 32 files (16 `.fnt` + 16 `.tga`) from
   `~/work/eu4-run/item23/gfx/fonts/` into it.
3. Start the game with the mod enabled; the mod files override
   the vanilla fonts of the same name.

## 3. Verification

- `make test` / `make all`: see PROGRESS.md for this item
  (documentation + external artefacts only; no repo code
  changed in this item).
- Generator self-check: vic_18.fnt parses back to 3,240 char
  lines; the glyph for U+623B (戻) has non-empty alpha in the
  atlas; CP1252 duplicates are present at both ids
  (e.g. U+2014 at 8212 and 151, U+2026 at 8230 and 133).
- Real-hardware check with a THROWAWAY test mod: the generated
  fonts were copied into a temporary mod in agent's own EU4
  user folder (enabled via a temporary `dlc_load.json`), the
  game was run with `eu4_smoke.sh`, and the test mod was
  removed again afterwards. Run `runs/20261121-162822`
  (no DLL): the main menu rendered normally in the new font
  (screenshot `shot_menu.png` checked visually: Single Player /
  Multiplayer / Tutorial / Credits / Options / Exit and the
  version line all legible, no corruption, no black screen),
  and the game ended by the Exit button (`eu4_wait=0`).
  So the .fnt/TGA form itself is accepted and English rendering
  is not broken.

## 4. Finding: the .fnt parser rejects every id >= 256

The same run's `error.log` contains 120,880 lines of
`[bitmapfont.cpp:436]: Invalid character ID` (about 3,022 per
font x 16 fonts, repeated per load). Comparing vic_18's
rejected ids against its .fnt: the accepted ids are EXACTLY
the 218 ids <= 0xFF; every id >= 0x100 was rejected. In other
words, the stock `CBitmapFont` loader has its own code-point
ceiling that no vanilla font ever hits, and a generated font's
Japanese glyphs are dropped at load time even though the files
are well-formed.

The same rejection count (120,880) appeared in two further
smoke runs with `EU4DLL_ENABLE_DECODE=1`
(runs/20261121-163222 and runs/20261121-163634), BUT in those
runs (and in two more launches afterwards) the DLL's usual
activation markers - the `[DIAGNOSTIC-RAW] crt_constructor
entered` stderr lines and a fresh `pattern_eu4jps.log` - were
absent, unlike every DLL run earlier today up to 16:07, with
the same .so (built 15:59, md5 unchanged) and the same EU4
binary. The cause of that change is UNPROVEN and was not
identified in this item. Therefore:

- It is NOT established whether the item 17 limiter patch
  (render-path code point ceiling 0xFF -> 0xFFFF) also covers
  this parser check, because the patch's presence in the
  rejection runs could not be confirmed.
- Either way, item 24 cannot succeed until (a) DLL activation
  in smoke runs is restored/confirmed, and (b) the
  bitmapfont.cpp parser check is investigated and, if it is a
  separate check, patched like the other Font injectors.
  This joins the two blockers already recorded in item 22
  section 5 (the item 20 null-glyph guard and the
  unidentified Game Browser path).

## 5. Known constraint: texture size cap

Three atlases exceed the vanilla 16 MiB `LoadTexture` file
size cap measured in item 18: vic_36.tga (33 MiB),
vic_29.tga and garamond_24.tga (17 MiB each). The item 18
FontSizeLimit patch raises the cap to 64 MiB, but only when
the decode opt-in patches are actually applied, so these
three fonts depend on the DLL being active; the other 13 are
under the cap. (In the no-DLL test run above the menu still
rendered normally, because the menu does not use vic_36 /
vic_29 / garamond_24.)

## Next

- Owner: place the files per section 2.
- Item 24 (after placement): Game Browser visual check of the
  Japanese replacement - expected to still fail until the
  section 4 parser check (and the item 22 blockers) are dealt
  with; record the actual outcome either way.
