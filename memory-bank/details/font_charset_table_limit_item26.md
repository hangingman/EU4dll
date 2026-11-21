# Font charset table limit: duplicate IDs and crash root cause (item 26)

Recorded 2026-11-21 (item 26). Scope: with the DLL active
(item 25 state restored), re-check the bitmapfont.cpp:436
Invalid character ID check, and investigate the Duplicate
character ID flood and the segfault seen when all 16 generated
fonts are loaded (run runs/20261121-171402, previous run).

## Result 1: the 436 check is covered by the item 17 limiter

- Run runs/20261121-171402 (DLL active, DIAGNOSTIC-RAW present,
  fresh pattern_eu4jps.log): bitmapfont.cpp:436 Invalid
  character ID count = 0 (was 120,880 with the DLL inactive).
- The item 17 CharCodePointLimiter patch (ParseFontFile
  cmp 0xFF -> 0xFFFF) covers the .fnt parser check at
  bitmapfont.cpp:436. No separate parser patch is needed.

## Result 2: every id >= 0x100 is reported Duplicate - table is 256 entries

Disassembly evidence (eu4 v1.37.5 binary):

- CBitmapCharacterSet is embedded in CBitmapFont at +0x100.
  Its glyph table is exactly 0x100 pointers: the CBitmapFont
  ctor memsets 0x800 bytes at +0x100, and the
  CBitmapCharacterSet destructor iterates exactly 0x100
  entries before destroying the kerning unordered_map that
  follows the table at charset+0x800.
- ParseFontFile (after the limiter patch) checks and stores
  glyphs at charset + id*8 with no bounds check
  (cmpq $0,0x100(%rax,%rcx,8) at VA 0x204e385; store at
  VA 0x204e563). For id >= 0x100 that address is no longer a
  glyph slot:
  - id 0x100 reads charset+0x800, the first word of the
    kerning unordered_map (libstdc++ _Hashtable bucket
    pointer, non-null after construction) -> always
    "Duplicate".
  - Larger ids read/write other CBitmapFont fields (the
    0x28-byte color array at this+0x960..0x3160, etc.) or,
    for ids in the tens of thousands, arbitrary heap memory
    beyond the object. Non-zero words report "Duplicate";
    zero words take a glyph pointer write into unrelated
    memory (heap corruption).

Minimal reproduction (this run, runs/20261121-172215):
a throwaway test mod (removed afterwards) whose standard.fnt
contains only the vanilla-range ids (<= 0xFF) plus three
added lines, id=256, id=1000 and id=8199 (copies of the id=65
line). All three were reported Duplicate (bitmapfont.cpp:431),
each twice (the font is parsed twice during startup),
Invalid character ID = 0, and the game reached the main menu
and ended by the Exit button (eu4_wait=0). The menu
screenshot was checked visually: normal English, no
corruption. This corrects the previous run's reading that
duplicates start at 8199: the generated .fnt files contain
no ids between 256 and 8198, so 8199 was merely the first
high id present in those files.

## Result 3: the full-font crash is consistent with the same overflow

In runs/20261121-171402 (all 16 generated fonts, 3,022 ids
>= 0x100 each), error.log has 116,338 Duplicate lines and no
Invalid lines, and EU4 segfaulted ~4s after launch
(eu4_wait=11, minidump eu4_20261121_171407, single-frame
stack). With ~48k high-id registrations across the fonts,
some slots land on zero words in the heap and take glyph
pointer writes into unrelated allocations; the crash is the
expected end state of that corruption. The minimal run
(3 high ids, all landing on non-zero words, no writes)
did not crash.

## Conclusion

- Item 26's original question is answered: the 436 check
  needs no new patch; the limiter covers it.
- But generated Japanese glyphs are NOT loaded: every
  id >= 0x100 is rejected as a false Duplicate, and the
  registration path is memory-unsafe for high ids. Simply
  widening the ParseFontFile compare (item 17) is not a
  viable route to loading wide glyphs on its own.
- What a real fix requires (next item, not done here):
  give CBitmapFont a glyph table that can actually hold
  wide ids - e.g. hook ParseFontFile registration and all
  glyph fetch sites to a side table owned by the DLL, or
  relocate/expand the embedded table and fix up every
  indexer (ParseFontFile, CBitmapCharacterSet::SetCharacter,
  GetWidthOfString / Render* fetch sites, the destructor's
  0x100 loop, SetKerning's glyph access). The fetch-side
  hooks of items 19/20 already replicate some fetch sites
  for the main text path, but font-internal indexers also
  access the table directly.
- Item 27 (Japanese display re-check) must NOT be run until
  this is resolved: with the current limiter + generated
  fonts the game can segfault during font load.

## Verification

- Minimal smoke runs/20261121-172215: DLL active
  (DIAGNOSTIC-RAW, dll_ok_count=1), Duplicate = 6 lines
  (3 ids x 2 parses), Invalid = 0, ended_by_exit_button,
  eu4_wait=0, menu screenshot visually normal English.
- Test mod and dlc_load.json removed after the run; the
  user folder is back to its previous state (no mod/ dir).
- make test / make all: see PROGRESS.md entry for this run
  (finished with make all; normal build verified by the
  /bin/true DIAGNOSTIC check, per the item 25 rule).
