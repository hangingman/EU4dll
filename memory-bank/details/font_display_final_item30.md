# Final Japanese display check (item 30)

Recorded 2026-11-21 (item 30). Scope: with item 29 complete
(all byte-width CBitmapFont fetch sites decode escapes),
place the item 23 generated fonts, open the Game Browser,
and check whether the Japanese SetText replacement
(`Back=戻る`) renders without corruption.

## 1. Setup

- Throwaway test mod `testfonts_item30` in agent's own EU4
  user folder with all 32 item 23 font files (hardlinks),
  enabled via a temporary `dlc_load.json`; removed after the
  run and the user folder restored (no `mod/` directory, no
  `dlc_load.json`).
- Normal build verified before the smoke: `make test`
  (10 modules passed), then `make all` run last; final .so
  md5 e3d3b28224ce4b712a8d8a5a03c94196 (unchanged from item 29
  step 5), DIAGNOSTIC-RAW lines present on the /bin/true
  preload check.
- Run: `eu4_multiplayer.sh`, `runs/20261121-192004-multiplayer`,
  env `EU4DLL_ENABLE_DECODE=1`, `EU4DLL_SETTEXT_PROBE=1`,
  `EU4DLL_SETTEXT_REPLACEMENTS="Back=戻る"` (same conditions
  as item 27, now with item 29 in place).

## 2. Result: NEGATIVE - Japanese not displayed; the button
##    now shows an ellipsis-like three dots instead

- DLL active: all JMP lines present, including every item 29
  byte-width site (GetWidthOfString, RenderToScreen x2,
  RenderToTexture x2, GetHeightOfString, Render3d x2).
  SetText mapping id=0 `result=applied` (escaped length 6).
- Font load is clean: Duplicate character ID = 0,
  Invalid character ID = 0, error.log has only 3 lines,
  no crash. The process was alive at the Game Browser
  screen; the script ended by kill, the known behaviour
  of this script on that screen.
- Visual (screenshots `shot_menu.png` /
  `shot_multiplayer.png`, checked visually): the main menu
  renders normally in the generated fonts, no corruption.
  The Game Browser bottom-left button does NOT show 戻る.
  It shows three small white dots at the text baseline
  (an ellipsis-like mark) and nothing else.
- Comparison with earlier states of the same button:
  item 27 (generated fonts, before item 29) showed the raw
  escaped bytes as glyphs (`I`, `b`, boxed-X, `0`);
  item 29 with vanilla fonts showed a completely empty
  button (decoded wide glyphs are null and skipped).
  Now, with generated fonts and all decode hooks in place,
  the button shows only the three dots. Something IS
  resolved and drawn, but it is not the two Japanese
  glyphs.
- Font data is not the cause: all 16 generated .fnt files
  contain both code points with normal metrics
  (id=25147 戻: width/xadvance 14-18 in the UI sizes;
  id=12427 る: same range), so a correct lookup would have
  a real glyph with a sane advance for either character.

## 3. Remaining path (candidate for a new item)

Two candidate explanations, not yet distinguished:

1. Ellipsis truncation upstream of the hooked render
   paths: a GUI-side measuring step that is not among the
   hooked sites still overestimates the decoded string
   width (or measures the raw escaped bytes), decides the
   text does not fit the button, and substitutes an
   ellipsis before any hooked render function sees it.
2. NOT_DEF substitution at this button's font instance:
   the decode reaches the draw path, but the side-table
   lookup misses for the specific CBitmapFont instance
   this button uses, so the NOT_DEF glyph (U+2026, an
   ellipsis) is drawn instead of the wide glyphs.

How to distinguish next time: add opt-in logging to the
byte-width hooks that records, per wide decode, the font
pointer, the decoded code point and hit/miss of the side
table lookup; also log which measuring function the GUI
button code calls for this text. If no wide decode is
logged for the button at all, explanation 1 holds and the
truncation site must be located; if a miss is logged,
explanation 2 holds and the registration side for that
font instance must be checked.

## 4. Conclusion

Item 30 is complete as a check: Japanese does NOT yet
display on the Game Browser button. Items 1-30 are now
all accounted for. The remaining work is the new candidate
item in section 3; no new item is started here without
owner instruction.
