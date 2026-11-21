# Japanese display re-check (item 27)

Recorded 2026-11-21 (item 27). Scope: with item 28 complete
(wide glyph side table), place the item 23 generated fonts,
open the Game Browser, and check whether the Japanese SetText
replacement (`Back=戻る`) renders without corruption. If the
unidentified rendering path from item 21 still blocks display,
identify that path as part of this item.

## 1. Setup

- Throwaway test mod `testfonts_item27` in agent's own EU4
  user folder with all 32 item 23 font files (hardlinks),
  enabled via a temporary `dlc_load.json`; removed after the
  run and the user folder restored (no `mod/` directory, no
  `dlc_load.json`).
- Normal build verified before the smoke: `make test`
  (10 modules passed), then `make all` run last; final .so
  md5 e89d5a3d2c25c4d3d514056043eb2f9e, DIAGNOSTIC-RAW lines
  present on the /bin/true preload check.
- Run: `eu4_multiplayer.sh`, `runs/20261121-181435-multiplayer`,
  env `EU4DLL_ENABLE_DECODE=1`, `EU4DLL_SETTEXT_PROBE=1`,
  `EU4DLL_SETTEXT_REPLACEMENTS="Back=戻る"` (same conditions
  as items 21/24, now with item 28 in place).

## 2. Result: NEGATIVE - Japanese not displayed, but the
##    font-side blockers are gone

- DLL active: DIAGNOSTIC-RAW lines present, SetText mapping
  id=0 `result=applied` (escaped length 6 for the 2-character
  replacement). The replacement itself now reaches the game.
- Font load is clean for the first time with the full fonts:
  Duplicate character ID = 0 (item 26 full-font run: 116,338
  plus a segfault), Invalid character ID = 0, error.log has
  only the usual unrelated lines, no crash. The process was
  alive at the Game Browser screen; the script ended by kill,
  the known behaviour of this script on that screen.
- Visual (screenshots `shot_menu.png` / `shot_multiplayer.png`,
  checked visually): the main menu renders normally in the
  generated fonts, no corruption. The Game Browser bottom-left
  button does NOT show 戻る. It shows four glyphs reading
  `I`, `b`, a boxed-X (NOT_DEF-like) glyph and `0`.

## 3. Path identification: the button is drawn byte-wise,
##    outside the TextView decode path

The four visible glyphs are exactly the escaped byte string
rendered byte by byte. Per the item 10 codec, 戻る encodes to
the 6 bytes `11 49 62 10 8B 30` (戻 U+623B -> `11 49 62`,
る U+308B -> `10 8B 30`). Read as single-byte glyph ids those
bytes are: 0x11 and 0x10 (escape bytes, no visible glyph),
0x49 = `I`, 0x62 = `b`, 0x8B (no CP1252 glyph in the font,
shown as the boxed-X placeholder), 0x30 = `0` - matching the
screenshot glyph for glyph.

So this button's text never passes through the five hooked
TextView functions (FillVertexBuffer etc.), where escape
decoding and - since item 28 step 3 - the wide glyph lookup
happen. It is drawn by one of the byte-width CBitmapFont
paths inventoried in item 28 step 4 (RenderToScreen /
RenderToTexture / GetWidthOfString family), which iterate
the raw bytes of the string and index the embedded glyph
table directly. Those sites were proven byte-width only and
correctly left unpatched for the wide-table purpose, but
they also never decode the escape sequences, so no font or
table fix can make Japanese appear through them.

## 4. Conclusion

Item 27 is complete as a check plus path identification:
with item 28 done, Japanese glyphs load and register
correctly and the SetText replacement is applied, but the
Game Browser button is rendered by a byte-wise CBitmapFont
path that does not decode escapes, so Japanese does not
display there. Displaying Japanese on this class of UI text
needs a new item: decode escapes (and resolve wide glyphs
via the side table) inside the byte-wise BitmapFont render /
measure functions, or intercept this button's text before
that path. Items 27 and 28 are now both complete; no new
item is started here without owner instruction.
