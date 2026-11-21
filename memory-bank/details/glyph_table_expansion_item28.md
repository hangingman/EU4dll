# Wide glyph table: design and indexer inventory (item 28, part 1)

Recorded 2026-11-21 (item 28, first of several runs).
Scope: design the fix for the 256-entry glyph table found in
item 26, and inventory every site in the v1.37.5 binary that
indexes that table. No runtime code is changed in this part;
implementation follows in the next runs of item 28, in the
order given under "Implementation plan".

## Background

- Item 26: `CBitmapCharacterSet` is embedded in `CBitmapFont`
  at +0x100. Its glyph table is exactly 0x100 pointers
  (charset ctor at VA 0x204d0cc memsets 0x800 bytes at the
  charset base; the charset destructor at VA 0x204d114
  iterates exactly 0x100 entries and then destroys the
  kerning unordered_map at charset+0x800).
- `CBitmapFont::ParseFontFile` checks and stores glyphs at
  charset + id*8 with no bounds check, so with the item 17
  limiter widened to 0xFFFF every id >= 0x100 is a false
  Duplicate or a wild write, and loading all 16 generated
  fonts segfaults (runs/20261121-171402).
- EU4CHS (the Chinese localisation DLL the owner pointed to)
  solves the same problem by replacing the glyph table with
  a code-point map. This design follows that direction, in
  the form that fits this codebase's existing patch style:
  a DLL-owned side table, with the registration path and
  every fetch path redirected to it for ids >= 0x100.

## Design decision: DLL side table, ids >= 0x100 only

- For id < 0x100 nothing changes: the embedded table, the
  charset destructor's 0x100 loop and all byte-range code
  (including kerning, whose keys are `unsigned char` on both
  the Set and Get side, VA 0x204d176 / 0x204d1d8) keep
  working exactly as in vanilla.
- For id >= 0x100 the DLL keeps a per-font side table:
  key = (CBitmapFont* / charset base pointer, code point),
  value = CBitmapCharacter* (the same 0x10-byte allocation
  ParseFontFile creates with operator new(0x10)).
  A D associative array or an open-addressing table owned by
  the DLL is sufficient; the generated fonts register at
  most 3,022 wide ids per font, 16 fonts.
- Ownership: side-table glyphs are allocated by the game's
  own operator new inside ParseFontFile, exactly as today.
  The charset destructor will not free them (it only walks
  the embedded 0x100 entries), so wide glyphs leak for the
  lifetime of the process unless the DLL frees them at font
  destruction. Fonts are loaded once at startup and live
  until exit in practice; the leak is bounded (about 48k
  glyphs x 0x10 bytes = 0.75 MiB across all generated
  fonts) and is accepted for the first implementation, to
  be revisited only if a font-reload path is ever hooked.
  This mirrors the EU4CHS map approach, which also keeps
  its glyphs in the replacement map.
- Everything stays behind the existing opt-in
  (EU4DLL_ENABLE_DECODE=1): the new patches are installed
  only on that path, like items 17-20.

## Registration path (ParseFontFile, VA 0x204de66)

Two sites, both verified unique in the whole binary by a
byte scan of the 58 MiB executable in this run:

1. Duplicate check, VA 0x204e385:
   `cmpq $0x0,0x100(%rax,%rcx,8)`
   bytes `48 83 BC C8 00 01 00 00 00` - **1 hit**.
   At this point rax = font base (the value loaded from
   0x8(%rsp)), rcx = zero-extended char id (from r13d).
   Patch plan: 14-byte absolute jump (the codebase's Linux
   jump form) to a DLL trampoline that, for id < 0x100,
   performs the original cmpq against the embedded table,
   and for id >= 0x100 compares the side-table lookup
   result against 0, setting flags identically, then
   returns to VA 0x204e38e (the `je` that follows).
   The patch overwrites 9 bytes of the cmpq plus the first
   5 bytes of the following code only if the jump needs
   them; the exact overwritten span and the displaced
   instructions must be re-verified at implementation time
   (the `je` at 0x204e38e is 6 bytes, so a 14-byte patch
   starting at 0x204e385 covers cmpq + je; the trampoline
   must therefore also reproduce the branch decision -
   i.e. return to 0x204e527 when the slot is empty and to
   0x204e394 when it is occupied - rather than relying on
   flags after the jump back. This is the same
   branch-reproduction style the item 19 hooks use.)
2. Glyph store, VA 0x204e563:
   `mov %rax,0x100(%rcx,%r13,8)`
   bytes `4A 89 84 E9 00 01 00 00` - **1 hit**.
   At this point rax = new glyph pointer, rcx = font base,
   r13 = char id (already moved from rcx at 0x204e527).
   Patch plan: 14-byte absolute jump to a trampoline that
   stores into the embedded table for id < 0x100 and into
   the side table for id >= 0x100, then returns to
   VA 0x204e56b. The store instruction is 8 bytes; the
   following bytes up to the next instruction boundary at
   or past 14 bytes must be displaced and re-verified at
   implementation time.

## Fetch path inventory (this run, objdump scan)

Method: disassembled the CBitmapFont address range
VA 0x204d000-0x2058000 and listed every scaled-index access
with displacement 0x100 (charset embedded in the font), plus
the charset-relative accesses in CBitmapCharacterSet itself.
Fetch sites that read `0x100(base,index,8)`:

| VA | Function | Status |
|---|---|---|
| 0x204ef59 | CBitmapFont::RenderToTexture | not hooked |
| 0x2051088 | CBitmapFont::RenderToTexture | not hooked |
| 0x2052189 | CBitmapFont::RenderToScreen | not hooked |
| 0x2053084 | CBitmapFont::RenderToScreen | not hooked |
| 0x2053d56 | CBitmapFont::GetHeightOfString | not hooked |
| 0x2054027 | CBitmapFont::GetWidthOfString | not hooked |
| 0x20546d7 | CBitmapFont::Render3d | not hooked |
| 0x2054cd0 | CBitmapFont::Render3d | not hooked |
| 0x205556a | CBitmapFont::FillVertexBuffer (site A) | item 19 hook |
| 0x2055ac4 | CBitmapFont::FillVertexBuffer (site B) | item 19 hook |
| 0x20561a0 | CBitmapFont::GetActualRequiredSize | item 19 hook |
| 0x205664f | CBitmapFont::GetRequiredSize | NOT covered (see note) |
| 0x2056875 | CBitmapFont::GetRequiredSize | item 19 hook |
| 0x2056df7 | CBitmapFont::GetActualRealRequiredSizeActually | NOT covered (see note) |
| 0x20570b9 | CBitmapFont::GetActualRealRequiredSizeActually | item 19 hook |

Note on the two NOT covered rows: GetRequiredSize and
GetActualRealRequiredSizeActually each contain TWO glyph
fetches, and the item 19 hooks sit at only one of them in
each function. What string each fetch serves (main text vs
a wrapped/secondary pass) must be read from the
disassembly at implementation time; both are in scope for
the side-table redirect if their index can exceed 0xFF.

Charset-relative sites (index applied to a charset pointer
passed as an argument, no 0x100 displacement):

- CBitmapCharacterSet::SetCharacter (VA 0x204d16c):
  `mov %rdx,(%rdi,%rax,8)`, takes an `int` id, so it is
  wide-capable in signature. No direct call site was found
  by a whole-binary call scan in this run (the symbol has
  no `call` referencing it in the scan output), so it is
  probably inlined at its callers or unused on the text
  .fnt path (ParseFontFile stores inline, above). Marked
  UNPROVEN; re-check before deciding it needs a redirect.
- SetKerning / GetKerning (VA 0x204d176 / 0x204d1d8): both
  index the table with an `unsigned char` first argument,
  so their index can never reach 0x100. No redirect needed;
  wide glyphs simply have no kerning, matching the
  generated .fnt files, which carry no kernings.
- Charset destructor (VA 0x204d114): iterates exactly
  0x100 entries. No redirect (see ownership above).

Out of the CBitmapFont range, functions that receive a
`CBitmapCharacterSet const&` and index it directly (map
text: CurveText at VA 0x1b5eac7, country-name generation)
work on byte-coded map strings, not on the escaped UI text
path; they are out of scope for item 28 and are recorded
here as a known limitation: map text keeps byte semantics.

## What the item 19/20 hooks must change

The five v1.37.5 decode-at-fetch hooks in main_text.d
currently return a null glyph pointer for code points
>= 0x100 (the item 20 crash guard). Once the side table
exists, that guard becomes a side-table lookup keyed by
the font base available at each site: hit -> the glyph
pointer, miss -> null (the current safe behaviour, which
all five call sites already null-check). The escape decode
itself (shifts, NOT_DEF fallback at 0x2026 for the
0x100-0xA00 band etc.) is unchanged.

The eight not-hooked fetch sites (RenderToTexture x2,
RenderToScreen x2, GetHeightOfString, GetWidthOfString,
Render3d x2) index the table with the raw character value
flowing through those functions. Before patching any of
them, the next run must establish, per site, the width of
the index register's source: if the value is a single byte
of a CString, a wide id can never reach the site and the
site is safe as-is (escaped bytes are consumed by the
hooked paths); if a site can see a decoded wide code
point, it gets the same side-table trampoline treatment
as the registration store.

## Implementation plan (next runs of item 28, in order)

1. Side-table module (new D module, pure helpers +
   unittests): register / lookup / clear keyed by
   (font base, code point), with the >= 0x100 gate.
2. ParseFontFile registration redirect: trampolines for
   the duplicate check (0x204e385) and the store
   (0x204e563), AOB patterns with hasSize(1) gating,
   opt-in only. Verify with the item 26 minimal font
   (ids 256 / 1000 / 8199): Duplicate must be 0, Invalid
   must stay 0, no crash, menu screenshot normal.
3. Item 19 hook change: >= 0x100 guard becomes a
   side-table lookup at all five sites.
4. Per-site width analysis of the eight not-hooked fetch
   sites; redirect any that can see wide code points.
5. Full check: all 16 generated fonts placed via the
   throwaway test mod, decode opt-in on: no Duplicate
   flood, no Invalid lines, no crash, English menu
   screenshot normal. Only then is item 28 done and
   item 27 (Japanese display re-check) unblocked.

Interim safety note: until step 2 lands, the generated
fonts must not be placed in a real mod together with the
limiter active - that combination is the item 26 crash.
The vanilla game without the generated fonts is unaffected.

## Verification (this part)

- AOB byte scans over the whole binary: both registration
  patterns have exactly 1 hit each (see above).
- Fetch inventory: objdump disassembly of
  VA 0x204d000-0x2058000, scaled-index accesses listed
  above; function attribution by nm symbol ranges.
- No code change in this part; make test / make all are
  run as usual and recorded in PROGRESS.md.
