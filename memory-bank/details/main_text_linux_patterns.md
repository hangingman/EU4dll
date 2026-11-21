# TextView (main_text) side Linux AOB pattern derivation for v1.37.5

Recorded 2026-11-21 (item 13). Scope: derive, from the Linux
v1.37.5 binary, the AOB patterns that the injectors in
`source/plugin/main_text.d` would need, and record the hit
count of each candidate over the whole binary. No injection
was enabled in this item: `main_text.d` is unchanged and
`TextView.init` stays commented out in `dllmain.d`.

## Method

- Binary: `eu4` v1.37.5, 60,526,352 bytes, non-PIE ELF.
  Virtual address = file offset + 0x400000 (same as item 12).
- Candidate functions were located by symbol (`nm -C -S`) and
  disassembled with objdump: `CBitmapFont::FillVertexBuffer`
  0x2055448 (2,882 bytes, the loop-2 / rendering side),
  `CBitmapFont::GetRequiredSize` 0x20565aa (1,980 bytes),
  `CBitmapFont::GetActualRequiredSize` 0x2055f92 (1,560
  bytes) and `CBitmapFont::GetActualRealRequiredSizeActually`
  0x2056d66 (3,278 bytes) (the loop-1 / measuring side), plus
  `CBitmapFont::GetWidthOfString` 0x2053f7c and
  `GetHeightOfString` 0x2053b88 as related measuring loops.
- Hit counts are whole-binary scans with the same method as
  items 9 and 12. Old (up to v1.33.3.0) patterns from
  `main_text.d` and the upstream v1.37 patterns were
  reconfirmed at **0 hits** each (proc1, proc2 both variants,
  proc3 hook and return-2, proc4, CopyBuff).

## Structural difference from Windows (applies to all injectors)

The Windows hooks patch a direct byte fetch
(`movzx eax, byte ptr [reg+reg]`) followed by a glyph-table
fetch (`mov reg, [R15+RAX*8]`) and a scale load
(`movss xmm3, [R15+0x848]`). The Linux loops do not fetch
bytes that way:

- Loop-1 and loop-2 functions obtain each character through a
  call to `CString::operator[](unsigned int)` (0x254c110),
  then `movzbl (%rax),%eax` on the returned pointer, then the
  glyph-table fetch `mov reg, 0x100(base,%rax,8)`.
- The glyph-table base offset is **0x100** (same as
  ParseFontFile in item 12) and the font scale is at
  **+0x940** on the font object (Windows proc1 used +0x848);
  it is consumed inline (`mulss 0x940(base)`) or loaded after
  the fetch, not as part of the fetch sequence.
- `movzbl (%rax),%eax` alone has **305 hits** in the whole
  binary, and `movzbl (%rax),%eax` with a 0x100-displacement
  glyph fetch within the next 20 bytes has **12 hits**
  (including RenderToTexture, Render3d, GetHeightOfString and
  ParseFontFile sites). Only the extended per-site patterns
  below are unique.
- Loop 1 is not one function on Linux: the measuring work is
  split over three near-duplicate functions
  (GetRequiredSize, GetActualRequiredSize,
  GetActualRealRequiredSizeActually), each with its own fetch
  site. A single Windows-style hook site per loop-1 injector
  therefore does not exist on Linux.

## Result per injector

### 1. mainTextProc1Injector (loop 2 char fetch) - FOUND, two sites in FillVertexBuffer

`CBitmapFont::FillVertexBuffer` contains two fetch+glyph
sites, both unique with context:

- Site A (advance / kerning pre-pass), VA 0x2055562:
  `movzbl (%rax),%eax; mov rcx,[rsp+0x68]; mov r15,0x100(%rcx,%rax,8); test r15,r15; je ...; movswl 0xc(%r15),%eax; ... mulss 0x940(%rcx),%xmm0`
  Pattern `0F B6 00 48 8B 4C 24 68 4C 8B BC C1 00 01 00 00 4D 85 FF`:
  **1 hit**. Extended 40-byte pattern through the `mulss`:
  also **1 hit**.
- Site B (vertex generation), VA 0x2055ac1:
  `movzbl (%rax),%eax; mov rax,0x100(%r12,%rax,8); test rax,rax; je ...; movss 0x940(%r12),%xmm9; movzwl 0x6(%rax),%ecx`
  Pattern `0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0 0F 84 60 03 00 00`:
  **1 hit** (extended 36-byte pattern through `movzwl`: also 1 hit).

The Windows return offset (+0x1B) and hook register contract
(R15 = font object, scale at +0x848) do not carry over: at
site A the font object is reloaded from the stack into rcx
and the glyph lands in r15; at site B the object is in r12
and the glyph in rax. Which site (or both) an escape hook
must cover is a design decision for items 14/15, not decided
here.

### 2. mainTextProc2Injector (loop 1 counting) - NOT FOUND as designed

The Windows injector patches a `movsxd` pair, extracts a
scratch-buffer address from a `lea` at a fixed offset
(`mainTextProc2BufferAddress`), and the hook copies every
counted byte into that buffer while saving the decoded code
point for proc3/proc4.

No counterpart of that structure exists in the Linux loop-1
functions:

- No RIP-relative `lea` to a global/static buffer occurs in
  FillVertexBuffer, GetRequiredSize, GetActualRequiredSize
  or GetActualRealRequiredSizeActually, so there is no
  BufferAddress to extract.
- The counting loops fetch each character via
  `CString::operator[]` (see above) and never copy the text
  into a scratch buffer.
- The only byte-copy loops in these functions are the
  colour-code (0xA3, section sign) identifier copies: after a
  `cmpb $0xa3,(%rax)` fetch, following identifier characters
  are copied into a **stack** buffer, bounded by
  `cmp $0x7e` (126). Each such site is unique -
  GetActualRequiredSize VA 0x2056177
  (`44 89 ED 41 83 FF 7E 77 AC 44 89 F8 41 FF C7 44 88 64 04 50`, 1 hit, buffer at rsp+0x50),
  GetRequiredSize VA 0x2056854
  (`83 FD 7E 77 B2 89 E8 FF C5 88 9C 04 A0 00 00 00 EB`, 1 hit, buffer at rsp+0xa0),
  GetActualRealRequiredSizeActually VA 0x2057041
  (`41 83 FE 7E 77 AC 44 89 F0 41 FF C6 88 9C 04 80 00 00 00 EB`, 1 hit, buffer at rsp+0x80) -
  but they copy only a colour-code name, not every counted
  character, so they are **not** proc2 counterparts.

Conclusion: proc2 cannot be ported in its Windows form. A
Linux decode design must either hook the fetch sites
themselves (proc4-style, below) in each loop-1 function or
find another place to keep the decoded code point; the
shared `s_lastCodePoint` hand-off between proc2, proc3 and
proc4 has no Linux anchor yet.

### 3. mainTextProc3Injector (loop 1 line-break) - hook-form candidate FOUND in loop 2; return-2 NOT FOUND

The Windows hook patches `cmp word ptr [RCX+6], 0 / jnz`
(glyph field +6 == 0 test) and separately locates a
return-2 site via a global-flag compare
(`cmp byte ptr [rip+...], 0 / je`).

- Hook form: the only `cmpw $0,0x6(reg)` followed by a
  conditional jump in the whole binary is in
  **FillVertexBuffer** (loop 2, not loop 1), VA 0x2055619,
  right after the site-A glyph fetch (glyph in r15):
  `66 41 83 7F 06 00 0F 85 AB 03 00 00`
  (`cmpw $0x0,0x6(%r15); jne +0x3ab`): **1 hit**; the masked
  generic form `66 ? 83 ? 06 00 0F 85` is also **1 hit**
  whole-binary. A second `cmpw` site exists in
  GetWidthOfString VA 0x2054098
  (`66 83 7D 06 00 44 0F 44 E8`, 1 hit) but it feeds a
  `cmove`, not a branch, so it is not the same hook form.
  Generic `cmpw [reg+6],0` (any form): 21 hits.
- Return-2: the old pattern
  `80 3D ? ? ? ? 00 0F 84 9A 01 00 00` and the upstream v1.37
  form `80 3D ? ? ? ? 00 0F 84 5F 01` are both **0 hits**,
  and no `80 3D` (global byte compare) occurs at all inside
  the four candidate functions (the masked generic form has
  57 hits whole-binary, all outside them). The Linux
  line-break path does not test a global byte flag in this
  form, or it is inlined elsewhere; unproven either way.

Conclusion: a proc3-style patch point exists structurally,
but in loop 2 and without its return-2 partner; the
two-return-address design of the Windows proc3 hook cannot
be reproduced from the evidence in this item.

### 4. mainTextProc4Injector (loop 1 char fetch) - FOUND, one unique site per loop-1 function (3 sites)

Each loop-1 function has its own fetch+glyph site, unique
with context (fetch via `CString::operator[]` return value):

- GetActualRequiredSize, VA 0x2056198:
  `0F B6 00 48 8B 4C 24 28 48 8B AC C1 00 01 00 00 48 85 ED 0F` - **1 hit**
  (glyph into rbp, object reloaded from rsp+0x28 into rcx).
- GetRequiredSize, VA 0x2056872:
  `0F B6 00 49 8B AC C5 00 01 00 00 48 85 ED 74 3D F3 41 0F` - **1 hit**
  (glyph into rbp, object in r13).
- GetActualRealRequiredSizeActually, VA 0x20570b6:
  `0F B6 00 49 8B AC C7 00 01 00 00 48 85 ED 74 42 F3 41 0F` - **1 hit**
  (glyph into rbp, object in r15).

Related: GetWidthOfString fetches from a raw `char*`
instead: VA 0x2053fd9 `42 0F B6 34 3B 84 C9 74 45 40`
(`movzbl (%rbx,%r15,1),%esi`, **1 hit**), with the glyph
fetch separate at VA 0x2054027
(`mov 0x100(%rdi,%rsi,8),%rbp`) after colour-code handling.

The Windows proc4 hook relied on the code point saved by
proc2 (`s_lastCodePoint`) and only re-fetched the glyph;
since proc2 has no Linux counterpart (above), a Linux proc4
would have to decode at the fetch site itself. Whether all
three loop-1 functions (plus GetWidthOfString) need hooks,
or only the ones on the visible-text path, is not decided
in this item.

### 5. mainTextProcCopyBuffInjector (disabled in the D port)

Already commented out in `main_text.d` init. Old pattern
`42 80 7B 3C 00 8B 45 E8`: **0 hits** (reconfirmed). No
Linux derivation attempted, matching its disabled status.

## Summary table

| Injector | Linux pattern / site | Hits | Status |
|---|---|---|---|
| Proc1 (loop2 fetch) | FillVertexBuffer site A @0x2055562, site B @0x2055ac1 (patterns above) | 1 each | derived, unique; two sites, coverage undecided |
| Proc2 (loop1 counting) | - | - | not found as designed; no buffer lea, only colour-code stack copies (unique, different role) |
| Proc3 (loop1 line-break) | FillVertexBuffer `66 41 83 7F 06 00 0F 85 AB 03 00 00` @0x2055619 | 1 | hook form derived but in loop 2; return-2 not found (0 for both known forms) |
| Proc4 (loop1 fetch) | GetActualRequiredSize @0x2056198, GetRequiredSize @0x2056872, GetActualReal @0x20570b6 (patterns above) | 1 each | derived, unique per function; 3 sites instead of 1 |
| CopyBuff (disabled) | old pattern | 0 | not derived (disabled upstream in this port) |

## What this means for items 14-15

- The fetch+glyph sites are ready as AOB material: proc1
  has two unique sites in FillVertexBuffer and proc4 has
  one unique site in each of the three loop-1 measuring
  functions (plus the separate GetWidthOfString form).
- The Windows hook architecture does not transfer: Linux
  fetches go through `CString::operator[]` calls, the scale
  offset is +0x940 (not +0x848), the glyph table base is
  +0x100, and loop 1 is split across three functions.
- Proc2 and the proc2->proc3/proc4 `s_lastCodePoint`
  hand-off have no Linux anchor, and proc3 has no return-2
  site. Item 14/15 must design the decode around the fetch
  sites themselves (decode where the byte is fetched), not
  around a port of the Windows proc1-4 hook set.
- No return addresses are fixed in this item: the Windows
  offsets (+0x1B / +0x1D / +0x12 / +0x10) are meaningless on
  Linux because the patched sequences differ in length and
  shape; they must be derived from the Linux instruction
  boundaries when the hooks are written (item 14).

## Sources

- Local: `source/plugin/main_text.d`,
  `memory-bank/details/decode_enablement_investigation.md`,
  `memory-bank/details/font_linux_patterns.md`.
- Linux binary `eu4` v1.37.5: `nm -C -S` symbol lookup,
  objdump disassembly of the `CBitmapFont` functions listed
  above, and whole-binary AOB scans performed in this run.
