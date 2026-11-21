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
