# TextView (main_text) Linux injection for v1.37.5 (item 19)

Recorded 2026-11-21 (item 19). Scope: implement the Linux
fetch-site hooks for the TextView side, using the patterns
derived in item 13 (`main_text_linux_patterns.md`) and the
item 14 absolute-jump patcher. Runs only through the existing
opt-in: `TextView.init` is called only when
`EU4DLL_ENABLE_DECODE=1` (item 15). Without the variable,
behaviour is unchanged.

## Design: decode at the fetch site

Linux has no proc2 scratch-buffer hand-off and no proc3
return-2 site (item 13), so the Windows proc1-4 architecture
is not ported. Instead each hook sits directly on a
`movzbl (%rax),%eax` fetch that follows a
`CString::operator[]` call: at entry `rax` points at the
current character, so the escape byte is at `[rax]` and the
following word at `[rax+1]`.

All five hooks share the same decode core (mirroring the
existing Windows `mainTextProc1_hook`):

- save the character pointer in `r11`;
- `movzx eax, byte [r11]`; if the byte is an escape byte
  0x10-0x13, decode the word at `[r11+1]`: 0x10 as-is,
  0x11 minus `SHIFT_2` (0x0E), 0x12 plus `SHIFT_3` (0x900),
  0x13 plus `SHIFT_4` (0x8F2); truncate to 16 bits
  (`movzx eax, ax`); advance that site's loop index by 2
  (per-site, below); if the code point is not above
  `NO_FONT` (0x98F), replace it with `NOT_DEF` (0x2026);
- on a non-escape byte, `eax` is just that byte;
- replicate the site's original glyph fetch (table at
  +0x100), and the original `test` where the return address
  points at the following conditional jump;
- return through the site's return-address global
  (`lea r11, [rip+global]; jmp qword ptr [r11]`).

No hook pushes or pops anything, so the stack-relative
operands of the original code (and of the two memory-index
sites) stay valid.

## Sites

| # | Function / VA | Patch len | Return | Index advance on escape |
|---|---|---|---|---|
| 1 | FillVertexBuffer site A, 0x2055562 | 16 | +16 (`test r15,r15`) | `add r14d, 2` |
| 2 | FillVertexBuffer site B, 0x2055ac1 | 14 | +14 (`je`) | `add ebx, 2` |
| 3 | GetActualRequiredSize, 0x2056198 | 16 | +16 (`test rbp,rbp`) | `add r13d, 2` |
| 4 | GetRequiredSize, 0x2056872 | 14 | +14 (`je`) | `add dword ptr [rsp+4], 2` |
| 5 | GetActualRealRequiredSizeActually, 0x20570b6 | 14 | +14 (`je`) | `add dword ptr [rsp], 2` |

- Site 1 pattern:
  `0F B6 00 48 8B 4C 24 68 4C 8B BC C1 00 01 00 00 4D 85 FF`
  (fetch; `mov rcx,[rsp+0x68]`; `mov r15,0x100(%rcx,%rax,8)`).
  The hook replicates both moves and returns at the
  `test r15,r15`, which runs in the original code.
- Site 2 pattern:
  `0F B6 00 49 8B 84 C4 00 01 00 00 48 85 C0 0F 84 60 03 00 00`
  (fetch; `mov rax,0x100(%r12,%rax,8)`; `test rax,rax`).
  The hook ends with `test rax,rax` so the flags are set
  for the `je` at the return address (the absolute jump
  does not modify flags).
- Site 3 pattern:
  `0F B6 00 48 8B 4C 24 28 48 8B AC C1 00 01 00 00 48 85 ED 0F`
  (fetch; `mov rcx,[rsp+0x28]`; `mov rbp,0x100(%rcx,%rax,8)`).
  Returns at the `test rbp,rbp`.
- Site 4 pattern:
  `0F B6 00 49 8B AC C5 00 01 00 00 48 85 ED 74 3D F3 41 0F`
  (fetch; `mov rbp,0x100(%r13,%rax,8)`; `test rbp,rbp`).
  Hook ends with `test rbp,rbp` for the `je` at return.
- Site 5 pattern:
  `0F B6 00 49 8B AC C7 00 01 00 00 48 85 ED 74 42 F3 41 0F`
  (fetch; `mov rbp,0x100(%r15,%rax,8)`; `test rbp,rbp`).
  Hook ends with `test rbp,rbp` for the `je` at return.

Every pattern is exactly 1 hit whole-binary (item 13,
reconfirmed in the smoke run: no match-count mismatch was
logged for any of the five). Sites 1-2 are installed by
`mainTextProc1Injector` and sites 3-5 by
`mainTextProc4Injector`, each under its own
`EU4Ver.v1_37_5` case, each gated by `hasSize(1)` and
patched independently via `PatchManager.addJmpPatch` with
the patch length above; any site whose count is not 1 is
left unpatched and flags the injector's unmatched error.

## Proc2 / Proc3 on v1.37.5

`mainTextProc2Injector` and `mainTextProc3Injector` are
unchanged: item 13 found no Linux counterpart for proc2
(no global-buffer `lea`, no whole-text copy) and no
return-2 site for proc3. They still return version errors
on v1.37.5, so the aggregated decode error log line still
appears under the opt-in; it is non-fatal (item 15 wiring),
exactly as the remaining Font injectors behaved in
item 17.

## Residual uncertainty

- The index-advance targets rest on the index storage
  identified per site by disassembly in this run (register
  indices r14d / ebx / r13d, and the stack dwords at
  `[rsp+4]` for GetRequiredSize and `[rsp]` for
  GetActualRealRequiredSizeActually, which those loops
  load, increment and store). They are exercised only on
  the escape path, which normal English text never takes,
  so the smoke run does not prove them.
- Japanese rendering itself is not proven here: the
  escape encoder is not yet wired into the SetText
  replacement path (item 20), and the end-to-end check is
  item 21.

## Verification

- `make test`: 9 modules passed. `make all`: OK.
  `git diff --check`: OK.
- Smoke `runs/20261121-152852` with
  `EU4DLL_ENABLE_DECODE=1 EU4DLL_SETTEXT_PROBE=1
  EU4DLL_SETTEXT_REPLACEMENTS="Back=Home"`:
  - `eu4_stdout.log` contains all five
    `JMP for mainTextProc1Injector (v1.37.5 site A/B) created.`
    and `JMP for mainTextProc4Injector (v1.37.5 ...) created.`
    lines, with no match-count mismatch for these patterns.
  - SetText mapping id=0 result=applied, `DLL [OK]` once,
    EU4 reached the menu and ended by the Exit button
    (eu4_wait=0).
  - The menu screenshot (shot_menu.png in that run) was
    checked visually: normal English main menu, no display
    corruption. This matters because the measuring and
    rendering loops now run through the new hooks for every
    ordinary character.

## What remains

- Item 20: wire `escape_codec` into the SetText
  replacement path so Japanese replacements are emitted in
  escaped form.
- Item 21: end-to-end Japanese display check on the real
  machine.
