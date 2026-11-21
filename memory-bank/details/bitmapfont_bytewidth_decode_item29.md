# Byte-width BitmapFont decode (item 29, step 1)

Recorded 2026-11-21 (item 29, first of several runs).
Scope: start decoding escape sequences in the byte-width
CBitmapFont paths identified by item 27. This step implements
the measuring path `GetWidthOfString` and records the
disassembly analysis of the two `RenderToScreen` fetch sites
that the next steps must handle. Item 29 is NOT complete.

## 1. Implemented: GetWidthOfString fetch hook

- Site: `CBitmapFont::GetWidthOfString(const char*, int, bool)`,
  glyph fetch at VA 0x2054027
  `mov 0x100(%rdi,%rsi,8),%rbp`.
- AOB (fetch + test + je + movswl head)
  `48 8B AC F7 00 01 00 00 48 85 ED 74 72 0F BF 45 0C`
  verified exactly 1 hit in a full scan of the 58 MiB binary
  (file offset 0x1c54027) in this run.
- Entry state at the fetch (from disassembly): RDI = font
  (this), RSI = zero-extended current byte, RBX = raw
  `const char*` string, R15 = sign-extended loop index
  (R14D), RDX = length. The fetch is reached either by
  fallthrough after the colour/format branches
  (0xA3/0xA4/0xA6/0xA7/0x40/0x7B divert before it) or
  directly by the `je` at VA 0x2053fe0 when the bool
  argument in CL is zero; both entries carry the same state.
- Hook `mainTextBitmapWidthV137_hook` in
  `source/plugin/main_text.d`, installed by the v1.37.5 case
  of `mainTextProc4Injector` (a measuring-function family),
  gated by `hasSize(1)`, opt-in only
  (`EU4DLL_ENABLE_DECODE=1`), 14-byte absolute jump.
  The 14-byte patch covers the fetch (8), the `test` (3),
  the `je` (2) and the first byte of the following
  `movswl 0xc(%rbp),%eax`, so the hook reproduces all of
  them: null glyph -> jump straight to the je target
  (VA 0x20540a6, patch start +0x7F); otherwise it performs
  the movswl (written as `movsx EAX, word ptr [RBP + 0xC]`
  because LDC inline asm rejects `movswl`) and returns
  after it (VA 0x2054038, +0x11).
- Decode rules are the same as the five TextView hooks:
  escape byte 0x10-0x13 plus the following word, shifts
  SHIFT_2 0x0E / SHIFT_3 0x900 / SHIFT_4 0x8F2, the
  (0x100, 0x98F] band maps to NOT_DEF 0x2026, ids < 0x100
  come from the embedded table, ids >= 0x100 go through
  `wideGlyphLookup` (side table, item 28). On escape the
  hook advances R14D by 2; the loop tail at VA 0x205419a
  (`inc %r14d`) adds the third byte.
- Register/alignment argument: the function prologue is
  4 pushes + `sub $0xa8`, so RSP % 16 == 0 at the fetch;
  the wide path pushes exactly 4 registers (RAX/RCX/RDX/
  RDI) before calling the lookup, preserving alignment and
  the font pointer in RDI, which the following game code
  reuses for the scale at font+0x940.
- Known approximation: the kerning block after the fetch
  (VA 0x2054051+) still keys `GetKerning` with the raw
  escape byte as the first key and the byte after the
  escape sequence as the second. Kerning is byte-keyed by
  design (item 28), so no wide kerning can exist; any
  spurious entry for an escape byte is at most a small
  width offset. Recorded, not fixed.

## 2. Analysis recorded for the RenderToScreen sites

Both AOB contexts below were also verified exactly 1 hit
in the full binary scan in this run.

### Site 1 (width / line-break pass), fetch VA 0x2052189

- Context AOB: `48 8B 54 24 30 48 8B AC CA 00 01 00 00
  48 85 ED` (file offset 0x1c52184, 1 hit).
- Loop head VA 0x2052112: R13D = string index, R15D =
  length, R14 = raw string base, RCX = byte loaded with
  `movzbl (%r14,%rbp,1),%ecx` (RBP = sign-extended R13D).
  Colour/format bytes (0xA3/0xA4/0xA6/0xA7/0x40/0x24)
  divert before the fetch; escape bytes fall through.
  Each iteration also copies the raw byte into a scratch
  buffer at 0x3345190 indexed by EBX/R12D.
- Fetch: `mov 0x30(%rsp),%rdx` (font) then
  `mov 0x100(%rdx,%rcx,8),%rbp`; return would be the
  `test %rbp,%rbp` at VA 0x2052191. A 14-byte patch
  starting at VA 0x2052184 covers both movs and the first
  byte of the test, so a hook must reproduce the test and
  return at VA 0x2052194.
- Loop tail VA 0x2052620: `inc %r13d`, so a hook must add
  2 to R13D on escape for a total advance of 3. The
  kerning block after the fetch calls `CString::operator[]`
  with R13D and R13D+1, so after the +2 advance it would
  read the two bytes following the escape sequence; same
  byte-keyed kerning approximation as GetWidthOfString.
- This pass also appends the scratch buffer to the global
  `pText` string at 0x333d450 (strcat at VA 0x205228c) in
  the word-wrap branch, which is what site 2 iterates.

### Site 2 (draw pass), fetch VA 0x2053084

- Context AOB: `48 8B 7C 24 30 4C 8B AC C7 00 01 00 00
  4D 85 ED` (file offset 0x1c5307f, 1 hit).
- This loop does NOT read the original string: its head
  at VA 0x2052ecd loads the byte from the global `pText`
  buffer (`movzbl 0x333d450(%rbx),%eax`, RBX =
  sign-extended R15D index). Fetch: `mov 0x30(%rsp),%rdi`
  (font), `mov 0x100(%rdi,%rax,8),%r13`, then
  `test %r13,%r13`.
- Consequence: decoding only at site 1 does not by itself
  fix the draw pass, because site 2 re-reads the raw bytes
  that site 1 copied into `pText`. The next step must
  decide how the escaped bytes reach `pText` (or hook
  site 2 with its own index advance over the `pText`
  buffer, whose length/termination handling differs from
  the original string). This decision is the first task
  of the next item 29 run.

### Remaining sites (not yet analysed in depth)

RenderToTexture x2 (VA 0x204ef59 / 0x2051088),
GetHeightOfString (VA 0x2053d56) and Render3d x2
(VA 0x20546d7 / 0x2054cd0) from the item 28 step 4
inventory still need the same per-site loop analysis
before any patch.

## 3. Verification (this step)

- `make test`: 10 modules passed. `make all` run last;
  final .so md5 e8728a21fab4f164a83bbab2bb7a1b89,
  DIAGNOSTIC-RAW lines present on the /bin/true preload
  check (normal build, item 25 rule).
- Smoke `runs/20261121-183436-multiplayer`
  (`eu4_multiplayer.sh`, EU4DLL_ENABLE_DECODE=1,
  EU4DLL_SETTEXT_PROBE=1, Back replaced with the Japanese
  word, vanilla fonts): stdout log contains
  `JMP for mainTextProc4Injector (v1.37.5 GetWidthOfString, item 29) created.`
  alongside all five TextView and both registration JMP
  lines, SetText mapping id=0 result=applied, no crash,
  process alive at the Game Browser screen (script ended
  by kill, the known behaviour of this script there).
- Screenshots checked visually: main menu and Game Browser
  render normally in English, no corruption. The Game
  Browser bottom-left button still shows the byte glyphs
  (`I`, `b`, `0`-like) as in item 27: with vanilla fonts
  there are no wide glyphs to draw, and the RenderToScreen
  draw pass is not hooked yet. Expected at this step.

## 4. Next steps for item 29

1. Decide and implement the RenderToScreen handling
   (site 1 + site 2 / pText interaction above).
2. Per-site analysis and hooks for RenderToTexture,
   GetHeightOfString and Render3d, or a recorded reason
   any of them cannot carry a wide glyph.
3. Only then item 30: full check with the generated
   fonts placed.
# Step 2 draft (to append to bitmapfont_bytewidth_decode_item29.md)

## 5. Implemented: RenderToScreen site 1 + site 2 (step 2)

Decision on pText: site 1 keeps the full escape sequence in pText; site 2 decodes independently.

- Site 1 (width/line-break pass, fetch VA 0x2052189, patch at VA 0x2052184):
  hook mainTextRenderToScreenV137Site1_hook in source/plugin/main_text.d.
  Reproduces font load (RDX = [rsp+0x30]), fetch and test.
  Normal return VA 0x205219a (+0x16), null return VA 0x2052310 (+0x18C).
  On escape: writes payload bytes to scratch[RBX+1..+2] (scratch at
  0x3345190, RBX = current scratch index), adds 2 to R12D (tail copies
  R12D to EBX) and 2 to R13D (tail adds third byte). Scratch is
  strcat-ed into pText (0x333d450), so pText carries the full 3-byte
  sequence. Wide path spills XMM1-XMM3 low halves (movss) around the
  lookup call because they are live across this fetch; pushes
  RAX/RDX/RDI/RSI + sub 48 keeps RSP % 16 == 0.
  Index sign extension uses shl/sar pair (LDC asm rejects movsxd).
- Site 2 (draw pass, fetch VA 0x2053084, patch at VA 0x205307f):
  hook mainTextRenderToScreenV137Site2_hook. Reproduces font load
  (RDI = [rsp+0x30]), fetch and test. Normal return VA 0x2053095
  (+0x16), null return VA 0x20533e1 (+0x362). Byte is re-read from
  pText at RBX (sign-extended R15D); on escape decodes the word at
  pText[index+1], advances R15D by 2 (tail at VA 0x2053959 adds the
  third). RBP (pText length) is not touched. Wide path spills
  XMM0-XMM5 low halves and restores RDI (font) after the call.
- Both AOBs re-verified exactly 1 hit in a full binary scan in this run.
- Kerning in both passes stays byte-keyed (recorded approximation,
  same as GetWidthOfString).

## 6. Verification (step 2)

- make test: 10 modules passed. make all run last; final .so md5
  049ffb5c6c7cc8583ab0abc888bbc8c0, DIAGNOSTIC-RAW lines present
  on the /bin/true preload check (normal build, item 25 rule).
- Smoke runs/20261121-184743-multiplayer (eu4_multiplayer.sh,
  EU4DLL_ENABLE_DECODE=1, EU4DLL_SETTEXT_PROBE=1, Back replaced
  with the Japanese word, vanilla fonts): both RenderToScreen
  JMP lines present alongside all earlier JMP lines, DLL [OK],
  SetText id=0 result=applied, no crash, process alive at the
  Game Browser screen (script ended by kill, the known
  behaviour there).
- Screenshots checked visually: main menu and Game Browser
  render normally in English, no corruption. The Game Browser
  bottom-left button still shows the byte glyphs (I, b, dot,
  0). With vanilla fonts a decoded wide glyph would resolve to
  null and be skipped (empty button), so the continued byte
  display indicates this button is most likely drawn through
  one of the remaining unhooked paths (RenderToTexture x2 are
  the prime candidates; GUI buttons commonly render to a
  texture once). This is the first analysis target of step 3.
- Item 29 is NOT complete. Next: step 3 - per-site analysis
  and hooks for RenderToTexture x2, GetHeightOfString and
  Render3d x2, or a recorded reason any of them cannot carry
  a wide glyph.
# Step 3 (2026-11-21, item 29 step 3): per-site analysis of the
# remaining five fetch sites - analysis only, no runtime code

Scope: RenderToTexture x2, GetHeightOfString, Render3d x2.
Method: objdump disassembly of each fetch with its loop head,
kerning block and loop tail, plus a full-binary AOB scan for
every site (58 MiB binary, VA = file offset + 0x400000).
Item 29 is NOT complete; no hook is installed in this step.

## 7. Common finding: all five sites are hookable the same way

- Every site obtains its byte through CString::operator[]
  (const version at 0x254c110, mutable at 0x254c10a). Both
  operator[] bodies are three instructions:
  `mov %esi,%eax; add (%rdi),%rax; ret` - i.e. a CString is a
  std::string whose data pointer sits at offset 0, and
  operator[](i) is exactly `*(char*)*str + i`. A hook can
  therefore read the two payload bytes of an escape sequence
  directly as `word ptr [[string] + index + 1]` without
  calling operator[] and without disturbing the call state,
  exactly like the raw `const char*` hooks of steps 1-2.
- At every site the colour/format parsing (0xA3/0xA4/0xA6/
  0xA7/0x40/0x7B family, plus the `|`/`_`/letter checks in
  the copy loops of GetHeightOfString / Render3d) diverts
  before the fetch; escape bytes 0x10-0x13 are in none of
  those sets, so they reach the fetch unmodified, as in the
  already-hooked paths.
- At every site the loop index is a single register (or, for
  RenderToTexture site 2, a register that the common tail
  increments), and the common loop tail adds exactly 1, so a
  hook advances the index by 2 on an escape, the same
  contract as steps 1-2. Kerning after each fetch stays
  byte-keyed (recorded approximation, as before).

## 8. Per-site register / patch map

### RenderToTexture site 1 - fetch VA 0x204ef59
- Loop head VA 0x204ef41: RDI = CString on the stack at
  0xc0(%rsp) (const operator[]), ESI = R14D = index.
  Byte: `movzbl (%rax),%eax` at 0x204ef51.
- Fetch: `mov 0x38(%rsp),%rcx` (font), then
  `mov 0x100(%rcx,%rax,8),%rbp`; `test %rbp,%rbp`;
  `je 0x204f018` (null target, +0xBF from the fetch).
  After a non-null glyph the code does
  `movswl 0xc(%rbp),%eax` at 0x204ef6a, so a patch starting
  at the movzbl (0x204ef51) must reproduce byte load, font
  load, fetch, test and that movswl head, returning at
  0x204ef6a (+0x19) or at the null target.
- Common tail: `inc %r14d` at VA 0x204f576, then compare
  against the length at 0x78(%rsp); hook adds 2 to R14D.
- AOB (from the movzbl):
  `0F B6 00 48 8B 4C 24 38 48 8B AC C1 00 01 00 00 48 85 ED
   0F 84 AE 00 00 00` = exactly 1 hit (VA 0x204ef51).

### RenderToTexture site 2 - fetch VA 0x2051088
- Loop head VA 0x205107a: RDI = R12 (CString, mutable
  operator[]), ESI = R14D = index.
  Byte: `movzbl (%rax),%eax` at 0x2051085.
- Fetch: `mov 0x100(%r13,%rax,8),%r11` (R13 = font / this);
  `test %r11,%r11`; `je 0x20513d9` (null target, +0x351
  from the fetch). The non-null path first reloads the
  scale `movss 0x940(%r13),%xmm8` at 0x2051099, so a patch
  at the movzbl returns at 0x2051099 (+0x14) or at the
  null target. XMM8 is live in this loop, so the wide path
  must spill it (it is not spilled by the step 1-2 hooks,
  which only cover XMM0-XMM5).
- Common tail: `inc %r14d` at VA 0x2051489, compare against
  0x8(%rsp); hook adds 2 to R14D. Note the null target
  0x20513d9 re-reads the byte at the same index for the
  newline checks (0x0A/0x0D) before falling into the same
  tail, which is consistent with a null wide glyph being
  skipped.
- AOB: `0F B6 00 4D 8B 9C C5 00 01 00 00 4D 85 DB
  0F 84 40 03 00 00` = exactly 1 hit (VA 0x2051085).

### GetHeightOfString - fetch VA 0x2053d56
- Loop head VA 0x2053d49: RDI = R14 (CString, const
  operator[]), ESI = EBP = index.
  Byte: `movzbl (%rax),%eax` at 0x2053d53.
- Fetch: `mov 0x100(%rbx,%rax,8),%rax` (RBX = font / this);
  `test %rax,%rax`; `je 0x2053dfc` (null target, +0xA6
  from the fetch). Non-null path continues with
  `movswl 0xc(%rax),%ecx` at 0x2053d67; a patch at the
  movzbl returns at 0x2053d67 (+0x14) or at the null
  target. The glyph pointer register is RAX itself, so
  the hook must keep the decoded id in a different
  register until the fetch is done.
- Common tail: `inc %ebp` at VA 0x2053eb2, then a GetSize
  compare; hook adds 2 to EBP.
- Caveat recorded: this function first runs a separate
  byte-copy loop (head around VA 0x2053ceb) that copies
  bytes into a stack buffer at 0x30(%rsp) indexed by R15D,
  diverting only on the `|`/`_`/letter checks. That copy
  is not the string the fetch loop reads (the fetch reads
  the original CString in R14), so decoding at the fetch
  does not need the copy loop changed for measuring; any
  later use of the copied buffer is a separate question if
  this function is ever hooked for drawing (it is not a
  drawing function).
- AOB: `0F B6 00 48 8B 84 C3 00 01 00 00 48 85 C0
  0F 84 95 00 00 00` = exactly 1 hit (VA 0x2053d53).

### Render3d site 1 (measuring pass) - fetch VA 0x20546d7
- Loop head VA 0x20546c9: RDI = RBP (CString, const
  operator[]), ESI = R15D = index.
  Byte: `movzbl (%rax),%eax` at 0x20546d4.
- Fetch: `mov 0x100(%r12,%rax,8),%rbx` (R12 = font / this);
  `test %rbx,%rbx`; `je 0x20547ef` (null target, +0x118
  from the fetch). Non-null path: `movswl 0xc(%rbx),%eax`
  at 0x20546e8; a patch at the movzbl returns at
  0x20546e8 (+0x14) or at the null target.
- This pass has the same preceding byte-copy loop shape as
  GetHeightOfString (stack buffer at 0x110(%rsp) indexed
  by R14D); the fetch reads the original CString in RBP,
  so the same caveat and the same conclusion apply.
- AOB: `0F B6 00 49 8B 9C C4 00 01 00 00 48 85 DB
  0F 84 07 01 00 00` = exactly 1 hit (VA 0x20546d4).

### Render3d site 2 (draw pass) - fetch VA 0x2054cd0
- Loop head VA 0x2054cc2: RDI = R13 (CString, mutable
  operator[]), ESI = R15D = index.
  Byte: `movzbl (%rax),%eax` at 0x2054ccd.
- Fetch: `mov 0x100(%r12,%rax,8),%rax` (R12 = font / this);
  `test %rax,%rax`; `je 0x205519d` (null target, +0x4CD
  from the fetch). Non-null path reloads the scale into
  XMM10 (`movss 0x940(%r12),%xmm10` at 0x2054ce1), so a
  patch at the movzbl returns at 0x2054ce1 (+0x14) or at
  the null target, and the wide path must spill XMM10.
  The glyph pointer register is RAX itself (same note as
  GetHeightOfString).
- The short AOB `0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0`
  has 4 hits in the whole binary (it also matches a
  FillVertexBuffer site and two unrelated sites), so the
  long form including the je target and the XMM10 reload
  is required: `0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0
  0F 84 BC 04 00 00 F3 45 0F 10 94 24 40 09 00 00`
  = exactly 1 hit (VA 0x2054ccd).
- Remaining verification before hooking this site: the
  exact common loop tail that increments R15D on the draw
  path (several `inc %r15d` exist in Render3d, e.g. at
  0x205496a in the measuring pass); the draw-pass tail
  must be pinned down first, because the hook's +2 has to
  land on the same register the draw tail increments.

## 9. Decision and split for the rest of item 29

- No site is unhookable: all five can carry a wide glyph
  with the decode-at-fetch design, using the CString data
  pointer at offset 0 for the payload word. There is no
  recorded reason to exempt any of them.
- They are nevertheless NOT implemented in this step: each
  site differs in patch start, return / null-return
  offsets, index register, glyph register and live XMM set
  (XMM8 at RenderToTexture site 2, XMM10 at Render3d
  site 2), and a wrong spill or return offset crashes the
  game (item 14 lesson). Implementing all five at once
  would make a smoke failure unbisectable.
- Split: step 4 = RenderToTexture site 1 + site 2 hooks
  (the prime suspects for the Game Browser button, which
  still showed byte glyphs after step 2; GUI buttons
  commonly render to a texture once). Step 5 =
  GetHeightOfString + Render3d site 1 + site 2 hooks,
  after pinning the Render3d draw-pass loop tail.
- Verification of this step: record-only change, no runtime
  code changed; `make test` / `make all` are run as usual
  and the tree is committed on the work branch.

# Step 4 (2026-11-21, item 29 step 4): RenderToTexture site 1 + site 2 hooks

Implemented: both RenderToTexture byte-width fetch sites now
decode escapes and resolve wide glyphs via the side table, in
source/plugin/main_text.d (mainTextRenderToTextureV137Site1_hook /
Site2_hook, installed from the Proc4 injector v1.37.5 case,
opt-in only). Both sites are in the same function
(CBitmapFont::RenderToTexture, VA 0x204e886; prologue 6 pushes +
sub 0x2888, so RSP % 16 == 0 at both fetches).

- Site 1 (measuring / line-break pass, fetch VA 0x204ef59, patch
  at the preceding movzbl VA 0x204ef51, patch length 16 = movzbl
  3 + font load 5 + fetch 8): hook keeps the operator[] result
  pointer in R11, loads the font into RCX from 0x38(%rsp),
  reproduces fetch + test + je. Normal return VA 0x204ef6a
  (+0x19, the original movswl, which also reuses RCX for the
  scale), null return VA 0x204f018 (+0xC7). On escape it adds 2
  to R14D (common tail at VA 0x204f576 adds the third byte).
  Wide path pushes RAX/RCX/RDX/RDI + sub 48 and spills
  XMM0-XMM5 low halves around the lookup call (insurance; the
  accumulators of this loop are stack-kept); RCX (font) is
  restored by the pop after the call.
- Site 2 (draw pass, fetch VA 0x2051088, patch at the preceding
  movzbl VA 0x2051085, patch length 14 = movzbl 3 + fetch 8 +
  test 3): hook keeps the operator[] result pointer in R10
  (the glyph result register is R11 itself, so the return jump
  also goes through R10), font is R13 (callee-saved, preserved
  by the lookup call). Normal return VA 0x2051099 (+0x14, the
  XMM8 scale reload), null return VA 0x20513d9 (+0x354). On
  escape it adds 2 to R14D (common tail at VA 0x2051489 adds
  the third byte). Wide path spills XMM0-XMM5 plus XMM8 low
  halves (XMM8 recorded live for this loop in step 3).
- Both AOBs re-verified in this run by a full byte scan of the
  58 MiB binary: site 1 pattern (from the movzbl, 25 bytes)
  exactly 1 hit at VA 0x204ef51, site 2 pattern (19 bytes)
  exactly 1 hit at VA 0x2051085.
- Recorded approximation (both sites, same as steps 1-2):
  kerning after the fetch stays byte-keyed, and the null
  targets re-read the byte at the already-advanced index for
  their newline checks (0x0A/0x0D); a payload byte is not a
  newline in practice, so a null wide glyph is simply skipped
  and the total advance stays 3 bytes.

## Verification (step 4)

- make test: 10 modules passed. make all run last; final .so
  md5 54a84fbd4cc3d52fa3d84496c3d33a1a, DIAGNOSTIC-RAW lines
  present on the /bin/true preload check (normal build,
  item 25 rule).
- Smoke runs/20261121-190418-multiplayer (eu4_multiplayer.sh,
  EU4DLL_ENABLE_DECODE=1, EU4DLL_SETTEXT_PROBE=1, Back replaced
  with the Japanese word, vanilla fonts): both RenderToTexture
  JMP lines present alongside all earlier JMP lines, DLL [OK],
  SetText id=0 result=applied, no crash, process alive at the
  Game Browser screen (script ended by kill, the known
  behaviour there).
- Screenshots checked visually: main menu renders normally in
  English, no corruption. The Game Browser bottom-left button
  is now EMPTY (no text), where steps 1-2 still showed the
  byte glyphs (I, b, boxed-X, 0). With vanilla fonts a decoded
  wide glyph resolves to null and is skipped, so an empty
  button is exactly the expected result if this button draws
  through RenderToTexture: the byte-wise display is gone and
  the decode now reaches this button's path. Whether the
  glyph actually appears with the generated fonts placed is
  the item 30 check (after step 5).
- Item 29 is NOT complete. Next: step 5 - GetHeightOfString +
  Render3d site 1 + site 2 hooks, after pinning the Render3d
  draw-pass loop tail (still open from step 3).
