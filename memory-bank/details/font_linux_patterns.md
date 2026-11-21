# Font-side Linux AOB pattern derivation for v1.37.5

Recorded 2026-11-21 (item 12). Scope: derive, from the Linux
v1.37.5 binary, the AOB patterns that the six injectors in
`source/plugin/font.d` would need, and record the hit count of
each candidate over the whole binary. No injection was enabled
in this item: `font.d` is unchanged and `Font.init` stays
commented out in `dllmain.d`.

## Method

- Binary: `eu4` v1.37.5, 60,526,352 bytes, non-PIE ELF.
  Virtual address = file offset + 0x400000 (verified: the
  limiter site is at file offset 0x1c4e366 and objdump shows it
  at VA 0x204e366).
- Candidate functions were located by symbol (`nm -C`) and
  disassembled with objdump: `CBitmapFont::CreateBuffers`
  0x204d524, `CreateBuffer` 0x204d564, `FreeBuffers` 0x204d5e0,
  `InitPostRead` 0x204dbb8, `ParseFontFile` 0x204de66,
  `CBitmapFont` ctor 0x204d234.
- Hit counts are whole-binary scans with `?` wildcards, the
  same method as item 9.

## Result per injector

### 1. charCodePointLimiterPatchInjector - FOUND, unique

Linux counterpart of the Windows `cmp edi, 0FFh / ja` site is
in `CBitmapFont::ParseFontFile`, where the character id read
from the font file is range-checked before its glyph entry is
registered:

```
204e366: 41 81 FD FF 00 00 00   cmp    $0xff,%r13d
204e36d: 0F 87 25 01 00 00      ja     204e498   (skip registration)
204e373: 41 83 FD 0A            cmp    $0xa,%r13d  (newline also skipped)
...
204e385: 48 83 BC C8 00 01 00 00 00
                                cmpq   $0x0,0x100(%rax,%rcx,8)
204e527: BF 10 00 00 00         mov    $0x10,%edi   (operator new 0x10)
204e563: 4A 89 84 E9 00 01 00 00
                                mov    %rax,0x100(%rcx,%r13,8)  (glyph store)
```

- Pattern `41 81 FD FF 00 00 00 0F 87 25 01 00 00`:
  **1 hit** in the whole binary (VA 0x204e366).
- The cmp alone (`41 81 FD FF 00 00 00`) has 23 hits, so the
  full pattern including the `ja` displacement is required.
- Register differs from Windows (edi -> r13d) and the branch
  displacement differs (+0x125), as expected from item 9.
  The patch semantics (which immediate byte to widen, and to
  what) are NOT decided here; that belongs to the enablement
  items (14/15).

### 2. fontBufferHeapZeroClearInjector - NO Linux counterpart

Windows-only by construction: it patches a `HeapAlloc` call
site reached via `mov rcx, cs:hHeap`. The Linux font buffer
path has no heap call site of this form: `CreateBuffers` /
`CreateBuffer` call `GfxCreateVertexBuffer` directly, and no
zero-clear call follows the buffer creation. `FreeBuffers`
contains a `memset` of 0x280 bytes over an unrelated array,
which is not a counterpart. This injector must be skipped on
Linux (same conclusion as item 9, now confirmed by reading
the Linux buffer functions in full).

### 3/4. fontBufferClear1Injector / fontBufferClear2Injector - no 0x3D88 site; one shared candidate class

Both Windows sites are `mov edx, 3D88h` immediates feeding a
buffer clear. On Linux:

- `BA 88 3D 00 00` (`mov edx,0x3d88`): **0 hits**.
- Any-register immediate `? 88 3D 00 00`: 7 hits, all outside
  the font code (token/persistent IDs, reconfirmed from
  item 9; the 4 `mov esi,0x3d88` hits are at VA 0xd4c5a7,
  0xd88b1e, 0xfa5119, 0x171e0ee, none in `CBitmapFont`).
- The only vertex-buffer size immediate in the Linux font
  buffer functions is **0x4B0** (1200), passed in edx to
  `GfxCreateVertexBuffer` with stride 0x1C in ecx, at exactly
  two sites (see injector 5). There are not two distinct
  clear sites on Linux; Clear1 and Clear2 do not map to two
  separate Linux sites.

### 5. fontBufferExpansionInjector - candidate sites identified (2), equivalence unproven

Windows site is `mov ecx, 3D88h` (0 hits on Linux, item 9).
The Linux structural counterpart candidates are the two
`GfxCreateVertexBuffer` call sites, which share the short
pattern `BA B0 04 00 00 B9 1C 00 00 00 41 B8 01 00 00 00`
(**2 hits**) and are individually unique with their call-site
context:

- `CBitmapFont::CreateBuffers` (base vertex buffer), VA
  0x204d53a: pattern
  `41 B9 48 9F 7D 02 BE 00 00 00 00 BA B0 04 00 00 B9 1C 00 00 00 41 B8 01 00 00 00`
  - **1 hit**.
- `CBitmapFont::CreateBuffer` (per-index buffers), VA
  0x204d58b: pattern
  `41 B9 8E 9F 7D 02 4C 89 F7 BE 00 00 00 00 BA B0 04 00 00 B9 1C 00 00 00`
  - **1 hit**.

Caveat: whether the 0x4B0 argument is the quantity that needs
expansion for double-byte glyphs (it is the size/count
argument of a GPU vertex-buffer creation, not a CPU glyph
table size) is unproven. The glyph table itself is indexed by
code point (`0x100(%rcx,%r13,8)` in ParseFontFile) and its
allocation was not identified in this item. Do not patch
0x4B0 on the assumption it equals the Windows 0x3D88 sites.

### 6. fontSizeLimitInjector - NOT FOUND

- Windows pattern `41 81 FE 00 00 00 01`
  (`cmp r14d, 1000000h`): **0 hits** (item 9, reconfirmed).
- Masked generic `81 ? 00 00 00 01` (cmp r/m32, 0x01000000):
  20 hits in the whole binary, **none** inside the
  `CBitmapFont` range (VA 0x204d000-0x2058000); the hits are
  at 0x175ed54, 0x21fac5d-0x246a314 and similar unrelated
  addresses.
- A grep for large-immediate compares (`0xffff`, `0x10000`,
  `0x100000`, `0x1000000`) over the whole `CBitmapFont` range
  returned nothing.
- Conclusion: no Linux counterpart of the size-limit compare
  was identified. It may use a different constant or be
  inlined into a caller outside `CBitmapFont`; unproven either
  way. This injector cannot be ported from the evidence in
  this item.

## Summary table

| Injector | Linux pattern | Hits | Status |
|---|---|---|---|
| CharCodePointLimiter | `41 81 FD FF 00 00 00 0F 87 25 01 00 00` @0x204e366 | 1 | derived, unique |
| HeapZeroClear | - | - | no Linux counterpart (skip) |
| BufferClear1 | `BA 88 3D 00 00` | 0 | no site; see 0x4B0 note |
| BufferClear2 | `BA 88 3D 00 00 48 8B 4D 28` equiv. | 0 | no second site |
| BufferExpansion | extended 0x4B0 patterns @0x204d53a / @0x204d58b | 1 each (2 shared) | candidate, equivalence unproven |
| FontSizeLimit | `41 81 FE 00 00 00 01` / masked generic | 0 in font range (20 elsewhere) | not found |

## What this means for items 13-15

- The limiter is the one Font patch that is ready to port:
  a unique Linux AOB exists in `ParseFontFile`.
- HeapZeroClear should be dropped from the Linux plan.
- The buffer clear/expansion patches cannot be ported as
  three separate 0x3D88 patches; if expansion is needed at
  all, it must be re-derived from what the 0x4B0 argument and
  the code-point-indexed glyph table actually bound. That
  question is still open after this item.
- FontSizeLimit has no identified site; enabling Font.init
  on Linux (item 15) must either find it elsewhere or record
  it as knowingly omitted.

## Sources

- Local: `source/plugin/font.d`,
  `memory-bank/details/decode_enablement_investigation.md`.
- Linux binary `eu4` v1.37.5: `nm -C` symbol lookup, objdump
  disassembly of the `CBitmapFont` functions listed above,
  and whole-binary AOB scans performed in this run.
