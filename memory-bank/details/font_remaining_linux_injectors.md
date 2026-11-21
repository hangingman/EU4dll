# Font-side remaining Linux injectors for v1.37.5 (item 18)

Recorded 2026-11-21 (item 18). Scope: settle the Font injectors
left open by item 12 - BufferClear1, BufferClear2,
BufferExpansion and FontSizeLimit. Implement what can be
implemented in the item 17 form (unique pattern, hasSize(1)
gate, opt-in only); record the rest with reasons and close
them. HeapZeroClear was already closed in item 12 (no Linux
counterpart).

## FontSizeLimit - IMPLEMENTED (site identified in texture loader)

Re-search method: whole-binary scans for every encoding of a
32-bit compare against 1000000h, plus symbol attribution of
every hit.

- Windows pattern `41 81 FE 00 00 00 01` (cmp r14d): 0 hits
  (unchanged from items 9/12).
- Masked generic `81 ? 00 00 00 01`: 20 hits (same set as item
  12). Attributed by nearest symbol, only ONE is in
  graphics/texture code:
  - VA 0x22a7edb, `CTextureHandler::LoadTexture`:
    `81 FB 00 00 00 01 72 19` = `cmp ebx,1000000h / jb +0x19`.
    ebx is the return of `CVirtualFile::GetSize()` for the file
    being loaded (set at VA 0x22a7cc3); below 16 MiB the file is
    read into the buffer, at or above it the load is rejected
    (size forced to 1, buffer freed). Font textures reach this
    loader through `CBitmapFont::InitPostRead` ->
    `CTextureHandler::AddTexture`.
  - The other 19 hits are unrelated: CTradeNode, lua
    (luaK_setoneret / luaK_dischargevars), boost::process,
    minidump writer, base64 encoder, get_protocol_family
    (network), Curl_ftp_parselist (8 hits), ssl3_setup_read_buffer,
    do_name_ex (OpenSSL).
- `cmp eax,1000000h` (`3D 00 00 00 01`): 11 hits, none in
  CBitmapFont / CTextureHandler (ranges 0x21d..., 0x2f8...,
  0x301..., 0x306..., 0x30a...).
- All-register `81 /7` forms: only the LoadTexture site above
  (ebx) and the get_protocol_family site (edi, 0x23bcdf1).

Implementation (`fontSizeLimitInjector`, new v1_37_5 case):
pattern `81 FB 00 00 00 01 72 19 BB 01 00 00 00` - the short
form `81 FB 00 00 00 01` alone is already exactly 1 hit in the
whole binary; the extended form keeps the gate meaningful for
future builds. Gated by hasSize(1); patch writes 0x04 at
offset 5 (last immediate byte), widening the cap from
01000000h to 04000000h (64 MiB), mirroring the Windows patch
(0x04 at offset 6 of its 7-byte form). Runs only via the
existing EU4DLL_ENABLE_DECODE=1 opt-in.

Residual uncertainty, stated plainly: the identification rests
on the constant, the compared value being a file size, the
reject-on-overflow behaviour, and uniqueness within graphics
code - not on a Windows-side disassembly of the original site.
If the Windows site was a different 1000000h compare that Linux
compiled away entirely, this patch widens the texture loader
cap unnecessarily; it changes no behaviour for files below
16 MiB either way.

## BufferClear1 / BufferClear2 - NOT IMPLEMENTED (no Linux site)

- The Windows sites are two distinct `mov edx,3D88h` buffer
  clears. On Linux there is no 3D88h font site at all
  (`mov edx,3D88h` 0 hits; any-register 7 hits, all token IDs,
  reconfirmed this item) and there are not two clear sites:
  the Linux font buffer functions contain no vertex-buffer
  clear. `CreateBuffers` / `CreateBuffer` pass the data
  pointer NULL to GfxCreateVertexBuffer (glBufferData with
  NULL data), and the only memsets in CBitmapFont are the
  glyph table (0800h bytes in the ctor / character-set ctor),
  the +0x3160 array (03C0h in the ctor, 0280h in FreeBuffers)
  and the +0x100 glyph table - none is a counterpart of the
  3D88h clears.
- Conclusion: the two Windows clear patches have no Linux
  counterpart to port. Closed as not applicable on Linux.

## BufferExpansion - NOT IMPLEMENTED (candidate disproven as equivalent)

Item 12 left the two GfxCreateVertexBuffer sites (VA
0x204d53a / 0x204d58b, immediate 0x4B0, extended patterns 1 hit
each, reconfirmed this item) as candidates with unproven
equivalence. This item read GfxCreateVertexBuffer itself
(VA 0x22ad267): its arguments are (context, data=NULL,
count=edx, stride=ecx, usage) - edx is stored as the buffer
vertex count and multiplied by the stride for glBufferData.
So 0x4B0 is a vertex COUNT of 1200 (stride 01Ch, 33600 bytes),
not a byte size in the role of the Windows 3D88h sites.

- The Windows expansion writes 010h over the third immediate
  byte (3D88h -> 103D88h, about 16x). The analogous write on
  0x4B0 would claim 1004B0h vertices for a buffer whose
  fill side (FillVertexBuffer and its callers) contains no
  1200-count check to expand together with it: batching is
  decided by the callers, not by this immediate. Expanding
  only the allocation therefore has no demonstrated effect on
  rendering, and there is no evidence the 1200-vertex batch
  size is what limits double-byte glyph display (an escaped
  Japanese character still produces one glyph, like ASCII).
- Conclusion: do not patch 0x4B0. Closed as not implemented;
  revisit only if item 19/21 testing shows a real
  1200-vertex batch truncation.

## Net state of Font.init on v1.37.5 after item 18

- Implemented: CharCodePointLimiter (item 17), FontSizeLimit
  (this item).
- Knowingly omitted on Linux, with reasons above/in item 12:
  HeapZeroClear, BufferClear1, BufferClear2, BufferExpansion.
  Their injectors still return version/unmatched errors on
  v1.37.5, so the opt-in decode log still reports injector
  errors overall; that remains expected and non-fatal
  (item 15 wiring).

## Verification

- `make test`: 9 modules passed. `make all`: OK.
  `git diff --check`: OK.
- Smoke `runs/20261121-151742` with
  `EU4DLL_ENABLE_DECODE=1 EU4DLL_SETTEXT_PROBE=1
  EU4DLL_SETTEXT_REPLACEMENTS="Back=Home"`:
  - `eu4_stdout.log` contains both
    `WriteMemory for charCodePointLimiterPatchInjector (v1.37.5) called.`
    and `WriteMemory for fontSizeLimitInjector (v1.37.5) called.`,
    with no Font size limit match-count mismatch, so the new
    pattern hit exactly once and the patch was applied.
  - SetText mapping id=0 result=applied, `DLL [OK]` once, EU4
    reached the menu and ended by the Exit button
    (eu4_wait=0).
  - The menu screenshot (shot_menu.png in that run) was checked
    visually: normal English main menu, no display corruption.
