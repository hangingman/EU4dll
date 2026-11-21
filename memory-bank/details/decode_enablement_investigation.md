# Enabling the escape decode side on Linux v1.37.5: investigation

Recorded 2026-11-21 (item 9). Question: what is needed to enable
`Font.init` / `TextView.init` (the TODO hooks in `dllmain.d`) on
Linux EU4 v1.37.5, so that escaped text (0x10-0x13 + two-byte code
point, see `details/mojibake_settext.md`) is actually decoded?
Investigation only: no implementation was changed in this item.

## Conclusion

Simply uncommenting the two `init` calls in `dllmain.d` does not
work. Every layer below the call site is still Windows / up to
v1.33.3.0 only:

1. No version case: `EU4Ver.v1_37_5` exists in `constant.d`, but
   neither `font.d` nor `main_text.d` has a case for it. Every
   injector falls into `default:` and returns a `version*` error.
2. No matching patterns: all AOB patterns in the local `font.d` /
   `main_text.d` (up to v1.33.3.0) **and** all v1.37 patterns from
   upstream `develop` (Windows) were scanned against the Linux
   v1.37.5 binary (60,526,352 bytes, non-PIE ELF): **zero hits for
   every pattern** (table below). The Linux binary is a different
   build (SysV ABI, different register allocation, no Windows heap),
   so Linux-specific patterns and hooks have to be derived from the
   Linux binary itself.
3. The patch machinery differs: `font.d` / `main_text.d` injectors
   use `PatchManager.addPatch` with the 5-byte rel32 `makeJmp`,
   which was already found unusable for far targets on Linux
   (the proven SetText hook uses a 14-byte absolute indirect JMP,
   a 17-byte verified instruction boundary and an ABI-preserving
   stub). The naked asm hooks also hard-code Windows-build register
   use (e.g. mainTextProc1: glyph table at `[R15+RAX*8]`, scale at
   `[R15+0x848]`).
4. `BytePattern.hasSize()` in this port is stubbed to always
   return `true` (`byte_pattern.d`), and `findIndexes` records
   only the first hit per section (.text / .rodata). Injectors
   that trust `hasSize(1, ...)` would dereference `getFirst()`
   even on zero hits. Any new injector must check the hit count
   itself, like the SetText hook effectively does.
5. One upstream font patch has no Linux counterpart in its current
   form at all: `fontBufferHeapZeroClearInjector` patches a
   Windows `HeapAlloc` call site (`mov rcx, cs:hHeap`). Linux has
   no such site (pattern: 0 hits, as expected).

What enabling therefore requires, in order, is listed under
"Required work" below. The upstream v1.37 work is still valuable:
it shows which game functions changed for 1.37 and what the new
Windows hooks look like, which narrows where to look in the Linux
binary. It does not provide drop-in patterns or hooks.

## Local code state

- `source/plugin/dllmain.d`: `Font.init` and `TextView.init`
  (= `plugin.main_text`) are commented out as TODO. Active inits:
  `loadTranslationMods()`, `ReloadTrace`, `SetTextHook`,
  `PluginVersion`. Note the aggregated `DllError` from these two
  inits is not checked in `hijackProcess` today (only
  `PluginVersion.init` gates `DLL [OK]`), so even a failing
  enablement would not be visible unless that is wired up.
- `source/plugin/constant.d`: `EU4Ver.v1_37_5 = 13750` exists and
  `Misc.getVersion()` returns it for this build
  (`plugin_version.d` also has the case). Version detection is not
  the blocker; the injector switches are.
- `source/plugin/font.d` (6 injectors, `init` aggregates them):
  `charCodePointLimiterPatchInjector`,
  `fontBufferHeapZeroClearInjector`, `fontBufferClear1Injector`,
  `fontBufferClear2Injector`, `fontBufferExpansionInjector`,
  `fontSizeLimitInjector`. Version cases end at v1.33.3.0.
- `source/plugin/main_text.d` (4 injectors + a disabled
  CopyBuff): `mainTextProc1Injector` (loop 2 char fetch),
  `mainTextProc2Injector` (loop 1 counting),
  `mainTextProc3Injector` (loop 1 line-break),
  `mainTextProc4Injector` (loop 1 char fetch). Version cases end
  at v1.33.3.0. Escape constants: `ESCAPE_SEQ_1..4` = 0x10-0x13,
  `SHIFT_2 = 0x0E`, `SHIFT_3 = 0x900`, `SHIFT_4 = 0x8F2`,
  `NO_FONT = 0x98F`, `NOT_DEF = 0x2026`. The D hooks for proc1/2/4
  are ports of the pre-1.37 Windows asm; upstream added separate
  `*V137` asm for proc1/2/4 because the register allocation
  changed (see below), so the local D hooks cannot be reused
  as-is even after new patterns are found.

## Upstream (matanki-saito/EU4dll) state, checked 2026-11-21

- Repository description: "master:1.34.2, dev:1.37.5.0". The
  `develop` branch is the 1.37 line: `plugin_64.h` has
  `v1_37_0_0 = 1370`, and `version.cpp` maps build numbers
  370-375 to `v1_37_0_0`, so Windows 1.37.5 is covered as
  `v1_37_0_0`. README states Linux is not supported upstream.
- `dll_main.cpp` (develop): init order is `Font::Init` first,
  then `MainText::Init`, then tooltip/button, map, dialog, etc.,
  and finally `CBitmapFont::Init` (a module this D port does not
  have at all). Errors are aggregated and validated
  (`Validator::Validate`).
- `font.cpp` (develop), v1_37_0_0 cases:
  - CharCodePointLimiter: pattern
    `81 FF FF 00 00 00 0F 87 6F 02 00 00 83` (only the branch
    offset differs from the v1.33 pattern `... 0F 87 2C 01 ...`),
    write 0xFF at +3.
  - HeapZeroClear: unchanged Windows pattern
    `48 8B 0D ? ? ? ? 4C 8B C3 33 D2`.
  - BufferClear1: pattern changed to
    `BA 88 3D 00 00 48 8B 4D` (register suffix truncated).
  - BufferClear2: pattern changed to
    `BA 88 3D 00 00 48 8B CB E8`.
  - BufferExpansion `B9 88 3D 00 00` and FontSizeLimit
    `41 81 FE 00 00 00 01`: unchanged, v1_37_0_0 added to the
    existing case list.
- `main_text.cpp` / `main_text_asm.asm` (develop), v1_37_0_0:
  - Proc1: **new pattern** `46 0F B6 04 09`
    (`movzx r8d, byte ptr [rcx+r9]`), return = address + 0x16,
    **new asm** `mainTextProc1V137` (char in RCX+R9, index in
    R15D, glyph table at `[R14+R8*8+0x120]`, scale at
    `[R14+0x968]`).
  - Proc2: **new pattern**
    `4C 63 CF 48 8B 55 F8 4C 03 CA 48 63 CE`, return + 0x1E,
    buffer address from the `lea` at +0x11, **new asm**
    `mainTextProc2V137` (movsxd r9, edi; base from [rbp-8];
    counters in ESI/ECX).
  - Proc3: same asm as before; return-2 pattern changed to
    `80 3D ? ? ? ? 00 0F 84 5F 01`, hook pattern shortened to
    `66 83 79 06 00 0F 85`, return1 = +0x12.
  - Proc4: **new pattern**
    `41 0F B6 01 49 8B 8C C6 20 01 00 00`
    (`movzx eax, byte ptr [r9]`), return + 0x13, **new asm**
    `mainTextProc4V137` (glyph table at `[R14+RAX*8+0x120]`).
  - Takeaway: for 1.37 the game recompiled these loops with
    different registers; upstream needed new patterns *and* new
    asm for 3 of the 4 hooks. The same will be true on Linux,
    with Linux-specific registers on top.

## Pattern scan against the Linux v1.37.5 binary (this run)

Method: byte-pattern scan (with `?` wildcards) over the whole
`eu4` file (60,526,352 bytes), performed offline on the home PC.
Patterns from local `font.d` / `main_text.d` are marked OLD,
upstream `develop` v1_37_0_0 patterns are marked UP.

| Pattern | Source | Hits |
|---|---|---|
| `81 FF FF 00 00 00 0F 87 2C 01 00 00 83` (limiter) | OLD | 0 |
| `81 FF FF 00 00 00 0F 87 6F 02 00 00 83` (limiter) | UP v137 | 0 |
| `48 8B 0D ? ? ? ? 4C 8B C3 33 D2` (heap zero clear) | both | 0 |
| `BA 88 3D 00 00 48 8B CF` (clear1) | OLD | 0 |
| `BA 88 3D 00 00 48 8B 4D` (clear1) | UP v137 | 0 |
| `BA 88 3D 00 00 48 8B 4D 28` (clear2) | OLD | 0 |
| `BA 88 3D 00 00 48 8B CB E8` (clear2) | UP v137 | 0 |
| `B9 88 3D 00 00` (expansion) | both | 0 |
| `41 81 FE 00 00 00 01` (size limit) | both | 0 |
| `48 63 C7 0F B6 04 18 F3 41 0F 10 9F 48 08 00 00` (proc1) | OLD | 0 |
| `46 0F B6 04 09` (proc1) | UP v137 | 0 |
| `48 63 D7 49 63 CE 4C 8B 55 80` (proc2) | OLD | 0 |
| `48 63 D7 49 63 CE 4C 8B 54 24 78` (proc2) | OLD | 0 |
| `4C 63 CF 48 8B 55 F8 4C 03 CA 48 63 CE` (proc2) | UP v137 | 0 |
| `80 3D ? ? ? ? 00 0F 84 5F 01` (proc3 ret2) | UP v137 | 0 |
| `80 3D ? ? ? ? 00 0F 84 9A 01 00 00` (proc3 ret2) | OLD | 0 |
| `66 83 79 06 00 0F 85` (proc3 hook, short) | UP v137 | 0 |
| `42 0F B6 04 12 49 8B 0C C7` (proc4) | OLD | 0 |
| `41 0F B6 01 49 8B 8C C6 20 01 00 00` (proc4) | UP v137 | 0 |
| `42 80 7B 3C 00 8B 45 E8` (copy buff) | OLD | 0 |

Relaxed probes:

- `88 3D 00 00` (the 0x3D88 font-buffer size immediate): 7 hits,
  but **all unrelated** - disassembly shows `mov esi, 0x3d88`
  (token/persistent IDs for `CToken` / `CSubjectInteraction` /
  `CCountry::ReadMember`), never a font buffer size in a
  `mov edx/ecx, imm` site. So the Linux font code does not use
  the 0x3D88 constant in this form; what the Linux font buffer
  size is, and whether it needs expansion at all, is unproven.
- `49 8B 0C C7` (`mov rcx, [r15+rax*8]`, glyph-table fetch):
  1 hit at file offset 0x1b58f90, but disassembly shows it is a
  false positive inside `CCountryDecisionsView::GetToolTip`
  cleanup code, not a text loop.

## Where the Linux decode sites actually are (candidates)

The Linux binary exports symbols, so the counterparts of the
Windows text loops can be located by function instead of by
pattern. The byte-fetch / glyph-lookup loops live inside
`CBitmapFont` (addresses are virtual addresses, non-PIE):

- `CBitmapFont::GetRequiredSize` 0x20565aa (1980 bytes) -
  counterpart of loop 1 (counting / required size).
- `CBitmapFont::GetActualRequiredSize` 0x2055f92 (1560 bytes)
  and `CBitmapFont::GetActualRealRequiredSizeActually`
  0x2056d66 (3278 bytes).
- `CBitmapFont::FillVertexBuffer` 0x2055448 (2882 bytes) -
  counterpart of loop 2 (glyph fetch for rendering).
- `CBitmapFont::RenderToTexture` 0x204e886 (12572 bytes),
  `CBitmapFont::RenderToScreen` 0x20519f8 (8592 bytes),
  `CBitmapFont::Render3d` 0x205449a (4013 bytes).
- `CBitmapFont::GetWidthOfString` 0x2053f7c,
  `CBitmapFont::GetHeightOfString` 0x2053b88.
- `CTextSprite::SetText` 0x20d9da4 (already hooked for
  replacement; its internal rendering goes through the above).
- Font buffer side: `CBitmapFont::CreateBuffers` 0x204d524,
  `CBitmapFont::ParseFontFile` 0x204de66,
  `CBitmapFont::InitPostRead` 0x204dbb8 - where a Linux
  counterpart of the font buffer / code-point-limit patches
  would have to be identified.

These are candidates by role, not confirmed hook sites: no
individual byte-fetch instruction inside them has been identified
yet. That identification (disassembly of the loop bodies, finding
the 1-byte fetch and the glyph-table indexing, deriving unique
AOBs with verified instruction boundaries) is the first concrete
step of the enablement work, mirroring how the SetText AOB was
derived earlier.

## Required work to enable decoding (for a later item)

1. Identify the Linux hook sites: disassemble the candidate
   `CBitmapFont` functions above, locate (a) the loop-1 counting
   fetch, (b) the loop-2 glyph fetch, (c) any code-point limit
   compare (counterpart of `cmp edi, 0xFF`) and (d) the font
   buffer sizing, and derive unique AOB patterns with complete
   instruction boundaries for each, as was done for SetText.
2. Write Linux asm hooks for those sites following the escape
   semantics of `main_text.d` (0x10-0x13 + 2-byte shifted code
   point, `SHIFT_2/3/4`, `NO_FONT`/`NOT_DEF`) but with the Linux
   register allocation read from the actual loop bodies - not
   the Windows (pre- or post-1.37) registers.
3. Add `EU4Ver.v1_37_5` cases to the `font.d` / `main_text.d`
   injector switches (or Linux-specific injectors next to the
   SetText hook), check pattern hit counts explicitly (do not
   rely on the stubbed `hasSize`), and use the proven Linux
   patching route (absolute JMP + stub, `patch_memory`) instead
   of the 5-byte rel32 `makeJmp` where the target is far.
4. Decide the fate of the Windows-only pieces: HeapZeroClear
   (no Linux counterpart in this form) must be skipped or
   re-derived from `CreateBuffers`/`ParseFontFile`; the
   0x3D88-based buffer clear/expansion patches likewise need a
   Linux sizing investigation before any equivalent is written.
5. Wire the init calls in `dllmain.d` behind the existing
   opt-in style, aggregate their `DllError` into the startup
   result so failures are visible in the log, and keep the
   current behaviour when the opt-in is off.
6. Verify in stages on the real machine (eu4_smoke.sh): first
   that all patterns hit exactly once and EU4 still starts and
   exits normally with the hooks installed but only ASCII text
   shown; only then feed escaped text (item 10's encoder) and
   check the screen (item 11).

Until step 1-5 are done, item 11 (on-screen Japanese check)
cannot be performed, and item 10's encoder can only be verified
by unit tests (round-trip against the decode rules above).

## Sources

- Local: `source/plugin/dllmain.d`, `font.d`, `main_text.d`,
  `constant.d`, `byte_pattern.d`,
  `source/plugin/patcher/patcher.d`,
  `source/plugin/localization/settext_hook.d`;
  `memory-bank/details/mojibake_settext.md`,
  `memory-bank/details/linux_patching_details.md`.
- Upstream: github.com/matanki-saito/EU4dll, branch `develop`
  (checked 2026-11-21): `Plugin64/font.cpp`, `main_text.cpp`,
  `main_text_asm.asm`, `dll_main.cpp`, `version.cpp`,
  `plugin_64.h`. Windows only; Linux is explicitly unsupported
  upstream.
- Linux binary: `eu4` v1.37.5 (60,526,352 bytes), pattern scan
  and `readelf`/`objdump` inspection performed in this run.
