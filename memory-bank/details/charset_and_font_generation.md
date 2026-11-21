# Character set collection and font generation method (item 22)

Recorded 2026-11-21 (item 22). Scope: (1) collect the character
set actually used by the translation yml body, mapped to the
font ids the escape_codec / decode side will look up; (2) decide
one Linux-usable way to generate a BMFont-format font (.fnt +
texture) for item 23; (3) check the upstream EU4fontcreate
code-point conventions against this repo's escape_codec.

## 1. Character set collected from the translation body

Source: the deployed mod body from item 8,
`~/.local/share/Paradox Interactive/Europa
Universalis IV/mod/eu4dll_translations/localisation/`
(145 yml files, UTF-8 with BOM). Only the quoted values were
collected (keys are localisation keys, not displayed text);
`\"` inside a value was unescaped before counting. The
collection script and full outputs are kept outside the repo
at `~/work/eu4-run/item22/` (`charset.tsv`: char, Unicode code
point, font id, occurrences; `charset_chars.txt`;
`font_ids.txt`).

- Files: 145. Lines: 126,941. Parsed entries: 126,796
  (matches the item 8 entry count).
- Distinct characters in values: 3,130.
  Total occurrences: 4,672,162.
- No character above the BMP (the encoder rejects those, and
  none occurs, so nothing is lost by that limit).

Distinct / occurrences by range:

| range | distinct | occurrences | note |
|---|---|---|---|
| U+0000-007F (ASCII) | 89 | 753,766 | incl. EU4 markup ($, section sign is below) |
| U+0080-00FF | 19 | 52,854 | section sign U+00A7 alone: 48,392 |
| U+0A00-2FFF | 9 | 3,251 | see special cases below |
| U+3000-30FF (kana + CJK punct.) | 174 | 2,462,999 | |
| U+3100-9FFF (kanji etc.) | 2,805 | 1,381,488 | |
| U+A000-FFFF | 34 | 17,804 | mostly fullwidth forms U+FF01-FF9E |

## 2. Font ids (the ids the .fnt must register)

The decode side recovers the original Unicode code point for
almost every character, so the font id is normally the code
point itself. The exceptions follow escape_codec exactly:

- CP1252 special cases (5 distinct in the data): the encoder
  emits one byte, so EU4fontcreate-style registration at the
  CP1252 byte id is required for the single-byte path:
  U+2014 -> 0x97, U+201C -> 0x93, U+201D -> 0x94,
  U+2022 -> 0x95, U+2026 -> 0x85.
  Decision: register these glyphs at BOTH ids (the CP1252 byte
  id and the Unicode code point). The decoded path looks up
  the Unicode code point (U+2026 is also the NOT_DEF
  substitute, so a glyph there is needed anyway), the
  single-byte path looks up the byte id. Duplicating 5 glyphs
  removes the ambiguity instead of guessing which path each
  UI element takes (item 21 showed paths differ per element).
- Shift band (0x100, 0xA00): the encoder shifts these by
  +0xE000 and the decoder does not shift back, so a glyph
  would have to be registered at code point + 0xE000.
  The translation data contains ZERO characters in this band,
  so the rule affects no glyph in the current set; it is
  recorded here so a future data update follows the codec,
  not the font tool (see section 3).
- Result: 3,130 distinct font ids from the translation data,
  no collisions after mapping, max id 0xFF9E.

Font set for item 23 = the 3,130 ids above UNION the vanilla
ids (standard.fnt / vic_18.fnt register 218 ids, U+0020-00FF),
so the replacement font keeps every glyph the stock font had,
plus the 5 duplicate registrations above. Three collected
characters have no glyph in the candidate source font
(U+2007 figure space, U+200B zero-width space, U+FE0E
variation selector): all are non-printing, and item 23 will
register them as empty zero-width glyphs (the vanilla space
glyph form: width 1, height 0).

## 3. EU4fontcreate conventions vs escape_codec

Upstream matanki-saito/EU4fontcreate README (read 2026-11-21):

- CP1252 0x80-0x9F characters are created at the CP1252 code
  point, not the UCS2 code point. AGREES with escape_codec
  (same UCS2ToCP1252 table). No conflict.
- Characters 0x100-0x1FF are shifted into the private use
  area at 0xE000 (example given: lambda is created at
  0xE3BB, not 0x03BB). The DIRECTION agrees with
  escape_codec (+0xE000 shift), but the stated band does
  not: the README text says 0x100-0x1FF while its own
  example U+03BB lies outside that band, and escape_codec
  shifts (0x100, 0xA00). Ground truth for this repo is the
  decoder in main_text.d / escape_codec, because that is
  what runs at display time. As recorded in section 2, the
  current data has no character in either band, so the
  discrepancy changes no glyph today. Decision: if a band
  character appears, register it at code point + 0xE000 per
  escape_codec; do not narrow the band to the README text.
- Code points 0x0E / 0x0F carry the date glyphs for
  (day) / (year) in EU4fontcreate. NOT ADOPTED: no such
  code point occurs in the translation values, and the
  date rendering path is out of scope here. Both kanji are
  in the set at their normal ids anyway.

## 4. Generation method decided for item 23

Candidates checked on the home PC (agent environment):

- AngelCode BMFont (bmfont64.exe), the tool EU4fontcreate
  wraps: Windows-only. Wine exists on the home PC but the exe
  is not in hand and the route is unverified; EU4fontcreate
  itself also documents Windows 10+ as a requirement.
  Not chosen.
- fontforge: not installed. Not chosen (no need; see below).
- msdf-bmfont-xml (Node): produces SDF/MSDF atlases, a
  different texture model from the vanilla fonts; the game
  expects plain alpha glyphs. Not chosen.
- DECIDED: a self-contained Python generator using Pillow
  and fontTools (both already installed: Pillow 11.1.0,
  fontTools 4.57.0). It rasterises each glyph, packs one
  TGA atlas, and writes a text .fnt in the exact vanilla
  form (info / common / char lines; vanilla files have no
  page or chars-count line - the texture name follows the
  .fnt basename - and kernings are optional for the parser).
  Proof of concept run in this item: `~/work/eu4-run/item22/poc/`
  (poc.fnt + poc.tga for a 15-char sample incl.
  U+623B U+308B U+63A5 U+7D9A) produced a vanilla-shaped
  .fnt and a 256x256 RGBA TGA, the same size/mode as the
  vanilla standard.tga.
- Source font: Noto Sans CJK JP Regular, already installed
  at /usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc
  (face index 0 is the JP face; Pillow loads it directly).
  Coverage measured with fontTools: 3,127 of the 3,130
  distinct characters; the 3 missing are the non-printing
  ones handled in section 2. Noto Serif CJK JP has identical
  coverage; Sans is chosen for UI legibility at small sizes.
- Size estimate: at 18 px, roughly 3,350 glyphs (set +
  vanilla + duplicates) at ~20x20 px cells need about
  1.4 Mpx, so a single 2048x1024 atlas (8 MiB as TGA) fits
  under even the stock 16 MiB texture cap; the item 18
  FontSizeLimit patch (64 MiB) leaves further headroom.
  Per-font sizes/names (vic_18, standard, ...) are item 23.

## 5. Known blockers that item 23/24 must not forget

Recorded here because they decide whether a generated font
can be seen at all; they are not part of item 22:

- The item 20 crash fix makes all five main_text hooks
  return a null glyph for code points >= 0x100, so on the
  hooked paths a Japanese glyph is skipped even if the font
  contains it. Lifting that guard safely (the glyph table
  itself is only 256 entries in the stock layout; see
  settext_escape_wiring.md) is separate work.
- Item 21 showed the Game Browser Back button does not use
  the hooked paths at all (escaped bytes leaked as raw
  single-byte glyphs). Its rendering path is unidentified.

## Verification

- Collection and coverage scripts ran on the home PC against the
  real 145-file body; counts above are their output.
- EU4fontcreate README and generate.py were read from the
  upstream repository on 2026-11-21.
- PoC .fnt/.tga generated and inspected (text output) in
  `~/work/eu4-run/item22/poc/`.
- No repo code changed in this item (documentation only);
  make test / make all results are recorded in PROGRESS.md.

## Next

- Item 23: generate the font with the decided method and
  place it under the translation mod gfx/fonts (or leave
  the generated files plus placement steps if the mod
  folder is not agent-writable).
