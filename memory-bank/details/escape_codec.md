# UTF-8 to escape encoder: implementation and conversion-table source

Recorded 2026-11-21 (item 10). Implements stage A of the item 7
design: a pure UTF-8 -> escaped-bytes encoder, verified by
round-trip unit tests against a decode test double. The encoder is
not wired into the SetText hook yet (that is stage B), and the
decode side in the game is still disabled (item 9), so nothing
about on-screen Japanese display is claimed.

## What was added

- `source/plugin/localization/escape_codec.d`, module
  `plugin.localization.escape_codec`:
  - `encodeCodePoint(dchar, out ubyte[])` and
    `encodeUtf8ToEscaped(const(char)[], out ubyte[])`: pure
    encoders. Invalid UTF-8 or a code point above the BMP returns
    false with no output; a partial encoding is never returned.
  - `decodeEscaped(const(ubyte)[], out dchar[])`: a decode test
    double, used only by unittests, so the round trip can be
    checked without the game.
  - Unittests in the same file: `make test` now passes 7 modules
    (was 6). Fixed vectors cover all four escape bands, plus
    round trips for ASCII, kana, kanji, mixed text, and the actual
    translation values found in item 8 (`戻る`, `ID接続`,
    `ロード`).

## Source of the conversion table

The table is a port of upstream matanki-saito/EU4dll, `develop`
branch, `Plugin64/escape_tool.cpp` (last upstream change to that
file: commit a0fedb2, 2024-08-24), functions
`convertWideTextToEscapedText`, `convertEscapedTextToWideText`,
`UCS2ToCP1252`, and `CP1252ToUCS2`. The local decode hooks in
`source/plugin/main_text.d` use the same constants
(`ESCAPE_SEQ_1..4` = 0x10-0x13, `SHIFT_2` = 0x0E,
`SHIFT_3` = 0x900, `SHIFT_4` = 0x8F2, `NO_FONT` = 0x98F,
`NOT_DEF` = 0x2026), which is what makes the port consistent with
this repo's decode side. The earlier design note (item 7) only
had the shift adjustments; the byte-avoidance set and the CP1252
special cases below come from the upstream encoder and were not
derivable from `main_text.d` alone.

## The encoding (per code point)

1. CP1252 special cases (27 code points, e.g. U+20AC -> byte
   0x80): emitted as a single byte.
2. Code points in (0x100, 0xA00) are first shifted by +0xE000
   (see "Does not round-trip" below).
3. Code points with high byte 0 are emitted as a single byte.
4. Otherwise the output is 3 bytes: escape byte, low byte, high
   byte (little-endian stored word). The escape byte is
   0x10 + 2 if the high byte is in the avoidance set, + 1 if the
   low byte is. The avoidance set (29 values, copied verbatim
   from upstream) is:
   A4 A3 A7 24 5B 00 5C 20 0D 0A 22 7B 7D 40 80 7E 2F 5F BD 3B
   5D 3D 23 3F 3A 3C 3E 2A 7C.
5. The stored word is adjusted so the decoder recovers the code
   point: escape 0x11 stores low + 0x0E (decoder subtracts
   SHIFT_2), 0x12 stores high - 9 (decoder adds SHIFT_3 = 0x900),
   0x13 does both (decoder adds SHIFT_4 = 0x8F2). 0x10 stores the
   word unchanged.

Worked examples (also fixed unittest vectors):

- 戻 U+623B: low 0x3B is in the set -> escape 0x11,
  bytes `11 49 62`.
- る U+308B: neither byte in the set -> `10 8B 30`.
- 続 U+7D9A: high 0x7D is in the set -> escape 0x12,
  bytes `12 9A 74`.
- 尻 U+5C3B: both bytes in the set -> escape 0x13,
  bytes `13 49 53`.

Escaped length is 3 bytes per escaped character, so the CString
capacity check must use the escaped length, as the item 7 design
recorded (SSO capacity 15 holds at most 5 Japanese characters).

## Deviations and limits (recorded, not hidden)

- **CP1252 byte value:** upstream `convertWideTextToEscapedText`
  writes `(BYTE)cp`, the truncated original code point, for the
  CP1252 special cases, which its own decoder
  (`CP1252ToUCS2`) does not invert (e.g. U+20AC would be written
  as 0xAC and read back as U+00AC). This port writes the mapped
  byte returned by `UCS2ToCP1252` (0x80 for U+20AC), which the
  decoder inverts exactly. This is the one deliberate deviation
  from the upstream code; it follows the upstream table's intent.
- **The (0x100, 0xA00) band does not round-trip:** upstream
  shifts it by +0xE000 before encoding and the decoder does not
  shift back (fixed vector: U+0101 -> bytes `10 01 E1` -> decoded
  as U+E101). The shift moves these code points out of the
  decoder's NOT_DEF zone (0x100 < cp < 0x98F becomes 0x2026).
  Japanese kana/kanji are above 0xA00 and are unaffected.
- **Above the BMP is rejected:** upstream works on 16-bit
  wchar_t, so the scheme has no representation for code points
  above 0xFFFF; the encoder returns false instead of truncating.
- **Boundary differences in NOT_DEF:** the decode test double
  follows upstream `convertEscapedTextToWideText`
  (sp > 0xFFFF, or 0x100 < sp < 0x98F, becomes 0x2026). The
  `main_text.d` hooks instead truncate to 16 bits and substitute
  NOT_DEF at cp <= 0x98F. The difference only affects code
  points the encoder never emits for representable input, but
  it is recorded here because the two decode rules are not
  identical.

## Verification

- `make test`: 7 modules passed (the new module's unittests
  included). `make all`: OK. `git diff --check`: OK.
- No smoke run: the encoder is not called from any runtime path
  yet, so a game launch would exercise nothing new.

## Next

- Item 11 (on-screen Japanese check) stays conditional: the
  decode side is not enabled (item 9 found it needs new Linux
  patterns and hooks), so item 11 is not performed until that
  separate work lands.
- Wiring this encoder into translation-file loading is stage B
  of the item 7 design and needs the owner's open decisions
  recorded there.
