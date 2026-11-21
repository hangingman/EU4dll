# Japanese display check after font placement (item 24)

Recorded 2026-11-21 (item 24). Scope: with the item 23 fonts
replacing the stock fonts, open the Game Browser and check
visually whether the Japanese SetText replacement
(`Back=戻る`) is rendered without corruption.

## 1. Setup

- The real translation mod folder is still not agent-writable
  (item 23), so placement was simulated exactly as in item 23:
  a throwaway test mod `testfonts_item24` in agent's own EU4
  user folder containing all 32 generated files
  (16 `.fnt` + 16 `.tga` from `~/work/eu4-run/item23/gfx/fonts/`,
  hardlinked), enabled via a temporary `dlc_load.json`.
  The test mod and `dlc_load.json` were removed after the run
  and the user folder was restored to its previous state
  (no `mod/` directory, no `dlc_load.json`).
- Run: `eu4_multiplayer.sh`, `runs/20261121-165545-multiplayer`,
  env `EU4DLL_ENABLE_DECODE=1`, `EU4DLL_SETTEXT_PROBE=1`,
  `EU4DLL_SETTEXT_REPLACEMENTS="Back=戻る"` (the same
  conditions as the item 21 check, plus the generated fonts).

## 2. Result: NEGATIVE - Japanese not displayed

- Visual (screenshots `shot_menu.png` and
  `shot_multiplayer.png`, checked visually): the main menu and
  the Game Browser render normally in the generated font, with
  no corruption and no black screen. The Game Browser's
  bottom-left button shows the English text "Back" - not the
  Japanese replacement, and not the raw escaped-byte glyphs
  seen in item 21 either. The process stayed alive at the
  Game Browser screen and the script ended by kill, which is
  the known behaviour of that script on this screen (item 2),
  not a crash.

## 3. Why: two independent blockers, both re-confirmed

1. The DLL did not activate in this run. `eu4_stdout.log`
   contains no `[DIAGNOSTIC-RAW]` lines at all (no
   crt_constructor, no SetText lines), and no fresh
   `pattern_eu4jps.log` was written (the copied log is the
   stale 09:15 one). This is the same unexplained absence
   first recorded in item 23 for every launch after 16:07
   today, now reproduced in a controlled run with the opt-in
   and probe variables explicitly set, with the same `.so`
   (md5 unchanged since the 15:59 build) and the same EU4
   binary. Cause remains UNPROVEN. Because the DLL never ran,
   the SetText replacement itself was never applied, which is
   why the button shows plain "Back".
2. The `.fnt` parser ceiling is independent of the DLL
   question and was reproduced with the fonts actually loaded:
   this run's `error.log` again contains exactly 120,880
   `[bitmapfont.cpp:436]: Invalid character ID` lines, the
   same count as the item 23 no-DLL run. Every generated glyph
   with id >= 0x100 is dropped at load time, so even a working
   replacement/decode path could not have drawn the Japanese
   glyphs from these fonts in this run.

## 4. Conclusion

Item 24 is complete as a check: with the generated fonts in
place, Japanese display is NOT achieved. English rendering in
the generated font is not broken. The remaining work is no
longer a display check but the two blockers above, in order:

- (a) Find why the DLL stopped activating in smoke runs after
  16:07 on 2026-11-21 and restore/confirm activation.
- (b) Investigate the `bitmapfont.cpp:436` parser check and,
  if it is separate from the item 17 limiter patch, patch it
  like the other Font injectors.

Plus the two blockers already recorded in item 22 section 5
(the item 20 null-glyph guard for code points >= 0x100 and
the unidentified Game Browser rendering path from item 21).
No new item is started here; items 1-24 are now all
accounted for.
