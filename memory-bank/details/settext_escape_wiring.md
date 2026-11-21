# SetText escape wiring and the item 19 hook crash fix (item 20)

Recorded 2026-11-21 (item 20, including the diagnosis of the
anomaly found by the previous item 20 run).

## Wiring (from the saved item20-uncommitted.patch, re-applied)

- `settext_hook.d`: a mapping whose replacement contains any
  non-ASCII byte is converted at load time with
  `escape_codec.encodeUtf8ToEscaped`; the stored
  `replacementLength` is the escaped length and the CString
  capacity check uses it. ASCII replacements are byte-identical.
  Unencodable replacements (invalid UTF-8, above BMP) are
  rejected at load with reason `unencodable-replacement`.
  Log line: `SetText escaped id=0 raw-length=6 escaped-length=6`
  for Back=<Japanese Back> (escaped bytes 11 49 62 10 8B 30).

## Diagnosis of the black-screen / exit-7 anomaly

The previous run reproduced the anomaly twice
(runs/20261121-154553, runs/20261121-154942): with
EU4DLL_ENABLE_DECODE=1 and an escaped Japanese replacement the
screenshots were uniform black and eu4_wait=7. The stdout log of
154942 shows it was in fact a crash, not a rendering failure:
after `SetText mapping id=0 result=applied`, EU4 wrote a
minidump (crashes/eu4_20261121_155001) and the process died
before the menu (summary says dead_030).

Isolation in this run: the same escaped replacement with decode
OFF (runs/20261121-155643) ran normally (alive at menu,
eu4_wait=0, normal screenshots). So the SetText conversion
itself is safe; the fault is in the item 19 hooks, on the
escape path only (English smoke had never taken it).

Root cause (binary evidence): the Linux CBitmapFont glyph
table at font+0x100 holds only 256 entries. The constructor
(CBitmapFont::C1, VA 0x204d234) memsets exactly 0x800 bytes at
+0x100, and ParseFontFile stores glyphs at
0x100(%rax,%rcx,8) with rcx bounded by the limiter. The item 19
hooks indexed that table with the full decoded code point:
kanji/kana are > 0x98F (kept as-is) and every other escaped
code point is replaced by NOT_DEF 0x2026 - both far beyond
entry 255 (e.g. U+623B reads at font+0x312D8). The resulting
garbage glyph pointer is dereferenced by the caller, which
crashes. All five hooked call sites check the glyph pointer
for null and skip safely, so a null result is the correct
"no glyph" behaviour for out-of-table code points.

## Fix

Each of the five v1.37.5 hooks in `main_text.d` now compares
the decoded code point with 0x100 before the glyph fetch:
code points >= 0x100 yield a null glyph pointer (the site's
glyph register is zeroed; sites whose return address is a
conditional jump still execute the original `test`). In-table
code points (including all normal single-byte text) take the
unchanged path. Consequence: with the stock font, Japanese
characters are skipped (zero width, not drawn) instead of
crashing; actually drawing them needs a font whose character
set contains them, which is beyond item 20 and is what item 21
must look at.

## Verify

- make test: 9 modules passed. make all OK. git diff --check OK.
- Smoke runs/20261121-155643 (decode OFF, Japanese): alive,
  eu4_wait=0 - conversion alone is safe.
- Smoke runs/20261121-155958 (decode ON, Japanese Back
  replacement): SetText escaped line logged, alive at menu,
  screenshots normal (shot_menu.png checked visually: normal
  main menu), ended_by_exit_button, eu4_wait=0.
- Smoke runs/20261121-160231 (decode ON, English Back=Home):
  ended_by_exit_button, eu4_wait=0 - no English regression.
