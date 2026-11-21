# GetHeightOfString crash with escaped text: survey

Recorded 2026-11-21. Read-only investigation: no game or DLL code
was changed. Question (from the real-machine verification in
`localize_escape_hook.md`): with localisation values stored
escape-encoded by the LocalizeYmlAddKey hook, the game SIGSEGVs in
`CBitmapFont::GetHeightOfString` (+0x1df, VA 0x2053d67) while
`CTutorial::Init` measures tutorial text. Is that path unhooked,
and if decode coverage is added there, what shape does it take?

## Answer in one line

The path is **not unhooked**: the item 29 step 5 hook
(`mainTextGetHeightV137_hook`) already patches this exact fetch
site, and the crash address 0x2053d67 is that hook's own normal
return address. The hook's wide path is buggy: it pushes RAX (the
decoded code point) before calling `wideGlyphLookup` and pops RAX
afterwards **without copying the lookup result anywhere**, so the
final `pop RAX` overwrites the glyph pointer with the code point
id. The game then dereferences `id + 0xC` at 0x2053d67 and faults.
The same latent bug exists, in identical shape, in
`mainTextRender3dV137Site2_hook`. Every other fetch hook copies
the result out of RAX (to RBP/R15/R11/RBX/R13) before popping, and
the one other hook whose glyph register is RAX
(`mainTextProc1V137SiteB_hook`) simply never pushes RAX. No new
decode coverage is needed; two existing hooks need the same
one-pattern fix.

## GetHeightOfString anatomy (VA 0x2053b88, size 0x3f4)

`CBitmapFont::GetHeightOfString(CString const&, int, int,
CVector2<int> const&, bool) const`. RBX = font (this), R14 =
CString, EBP = loop index, R13B = the bool argument (formatting
checks on/off). Float accumulators live in stack slots
([rsp], +4, +8, +0xC, +0x10, +0x1C), not in registers.

Per iteration (loop head VA 0x2053c33):

1. If R13B is set, the byte at the index is checked against the
   game's single-byte specials: 0xA7 (section sign), 0x7B '{',
   0x40 '@', 0xA3 (pound sign), with their own skip/measure
   handling. Escape lead bytes 0x10-0x13 match none of these, so
   an escape sequence at the index falls through to the fetch.
2. Fetch (VA 0x2053d49-0x2053d61): `CString::operator[](EBP)`
   returns the char pointer in RAX; `movzbl (%rax),%eax`
   (0x2053d53); `mov 0x100(%rbx,%rax,8),%rax` (0x2053d56) loads
   the glyph from the embedded table; `test %rax,%rax; je
   0x2053dfc` (null-glyph path: re-reads the byte and only acts
   on '\n'/'\r').
3. VA 0x2053d67 (**the crash instruction**):
   `movswl 0xc(%rax),%ecx` - the glyph's int16 field at +0xC,
   scaled by the float at font+0x940 and accumulated as the line
   height. It faults iff RAX is not a valid glyph pointer.
4. If the byte at glyph+0xE is non-zero, a kerning block runs
   (`GetKerning` over the current and next byte, both re-read via
   operator[]). The common tail at VA 0x2053eb2 is `inc %ebp`.

This is the function's only embedded-table fetch site.

## The existing hook and its bug

`mainTextGetHeightV137_hook` (item 29 step 5) patches 14 bytes at
VA 0x2053d53 (movzbl + fetch + test). Because the original fetch
is `mov 0x100(%rbx,%rax,8),%rax`, the glyph register is RAX
itself; the hook keeps the char pointer in R11, decodes an escape
(lead byte 0x10-0x13, word at [R11+1], shifts SHIFT_2 0x0E /
SHIFT_3 0x900 / SHIFT_4 0x8F2, NO_FONT 0x98F band mapped to
NOT_DEF 0x2026), adds 2 to EBP on an escape (the tail `inc %ebp`
adds the third byte), and for ids >= 0x100 calls
`wideGlyphLookup(font, id)`.

The wide path (JMP_G in the hook) then does:

```
push RAX            ; the decoded code point id
push RCX / RDX / RDI
sub RSP, 48 + XMM0-5 spills
call wideGlyphLookup        ; result in RAX
restore XMM, add RSP, 48
pop RDI / RDX / RCX
pop RAX             ; <-- RAX := the saved code point id again
JMP_H: test RAX, RAX        ; tests the id, not the pointer
```

The lookup result is discarded. For any escaped character the
hook returns to VA 0x2053d67 with RAX = id (0x100..0xFFFF after
the NOT_DEF mapping), the null test passes (id != 0), and
`movswl 0xc(%rax)` reads address id+0xC (0x10C..0x1000B, unmapped)
-> SIGSEGV at 0x2053d67, exactly the recorded crash (+0x1df).
A lookup **miss** is equally broken in the opposite way: the
null result is also overwritten by the id, so the game's own
null-glyph path (VA 0x2053dfc) is never taken from the wide path.

Register clobbering is not the cause: at this fetch site R11,
RSI, R8, R9, R10 are dead (no read before a rewrite anywhere in
the function; R11 is not used at all), the float state is in
stack slots, and XMM0 is zeroed immediately after the fetch.
`wideGlyphLookup` itself is sound: it returns the exact
game-allocated `CBitmapCharacter*` stored by the ParseFontFile
registration redirect, or null on a miss (plugin/glyph_table.d).

## Why it never fired before 2026-11-21

The step 5 verification (bitmapfont_bytewidth_decode_item29.md)
ran with English game text plus the SetText "Back" replacement.
Button labels are measured by GetRequiredSize /
GetActualRequiredSize, not by GetHeightOfString, and the
multi-line text measured by GetHeightOfString (tutorial /
CInstantTextBox content) was English, so this hook's wide path
never executed a single time. The localisation-escape run was
the first time a dictionary string containing escaped characters
reached GetHeightOfString: CTutorial::Init -> AddText ->
CInstantTextBox::UpdateScrollbarSize -> GetHeightOfString,
during CFrontEnd::RestoreDeviceObjects, before the main menu.

## Sibling measure paths: full inventory

All CBitmapFont string-measure fetch sites are already hooked,
and all but two hooks use the safe pattern (result copied out of
RAX before any pop, or RAX never pushed):

| Site | Fetch VA | Glyph reg | Wide-path result handling | State |
|---|---|---|---|---|
| GetRequiredSize (Proc4) | (item 19) | RBP | `mov RBP, RAX` after call | safe |
| GetActualRequiredSize (Proc4 GetActual) | (item 19) | RBP | `mov RBP, RAX` | safe |
| GetActualRequiredSize real (Proc4) | (item 19) | RBP | `mov RBP, RAX` | safe |
| Proc1 site A | (item 19) | R15 | `mov R15, RAX` | safe |
| Proc1 site B | (item 19) | RAX | RAX never pushed (only RCX/RDX) | safe |
| GetWidthOfString (BitmapWidth, item 29 step 1) | 0x2054027 | RBP | `mov RBP, RAX` | safe |
| RenderToScreen site 1 / site 2 (item 29 step 2) | - | RBP / R13 | copied before pops | safe |
| RenderToTexture site 1 / site 2 (item 29 step 4) | - | RBP / R11 | copied before pops | safe |
| Render3d site 1 (item 29 step 5) | 0x20546d7 | RBX | `mov RBX, RAX` | safe |
| **GetHeightOfString (item 29 step 5)** | 0x2053d56 | **RAX** | **result overwritten by pop RAX** | **broken (this crash)** |
| **Render3d site 2 (item 29 step 5)** | 0x2054cd0 | **RAX** | **result overwritten by pop RAX** | **broken (latent)** |

Notes:

- `CFont::GetRequiredSize` / `GetActualRequiredSize`
  (0x2076e00 / 0x2076e02) are 2-byte forwarding stubs to the
  CBitmapFont versions; no separate site.
- `CInstantTextBox::GetHeightOfText` (0x208c5a4) is a caller of
  GetHeightOfString, not a fetch site.
- Render3d site 2's first glyph dereference after its return
  address (VA 0x2054ce1, an XMM10 scale reload) is
  `movzwl 0x6(%rax),%ecx` at VA 0x2054ceb, followed by
  `movswl` reads at +8/+4/+0xA: with RAX = code point it faults
  the same way. It has not fired yet because Render3d draws map
  text, and no run so far rendered an escaped map label (country
  names on the main map with the localisation mod active would).
- font.d's two asm trampolines were also checked:
  `glyphDuplicateCheck_hook` copies the result to R11 before its
  pops and tests R11 (safe); `glyphStore_hook` ignores the call
  result and restores the glyph pointer in RAX on purpose (safe).

## Patch plan (no new coverage, fix the pattern in 2 hooks)

For both `mainTextGetHeightV137_hook` and
`mainTextRender3dV137Site2_hook`, mirror the proven Proc1 site B
shape: **do not push/pop RAX around the lookup call**. The id in
EAX is consumed by `mov ESI, EAX` before the call, so nothing
needs the saved copy.

- GetHeight hook: pushes become RCX, RDX, RDI (3 registers).
  To keep the call's stack alignment byte-identical, change
  `sub RSP, 48` to `sub RSP, 40`: total adjustment goes from
  4*8+48 = 80 to 3*8+40 = 64, both 0 mod 16, and the fetch
  point's RSP % 16 == 0 (prologue 6 pushes + sub 0xB8) is
  preserved at the call. XMM spill offsets within the sub area
  do not change.
- Render3d site 2 hook: identical push structure (RAX, RCX,
  RDX, RDI + sub 48, XMM0-5 + XMM10 spills), so the identical
  edit applies: drop push/pop RAX, sub 48 -> 40. Whatever the
  site's entry alignment is, it is preserved because the total
  adjustment stays a multiple of 16.
- After the fix, `test RAX, RAX` at JMP_H tests the real lookup
  result: a hit returns the glyph pointer to the game's
  continuation (0x2053d67 / 0x2054ce1), a miss takes the hook's
  null return (0x2053dfc / 0x205519d), which is the game's own
  null-glyph path - the same semantics the embedded fetch had.
- No AOB, patch length, return address, index advance, or
  decode-constant changes anywhere. The Proc4 injector installs
  both hooks unchanged.

Verification for the fix (for the follow-up implementation):

1. Rebuild, rerun the exact localisation-escape multiplayer
   run of 2026-11-21 (throwaway mod, EU4DLL_LOCALIZE_ESCAPE=1):
   CTutorial::Init exercises GetHeightOfString before the menu,
   so "menu reached, no crash" is already a strong signal.
2. Exercise Render3d site 2's wide path: enter the main map
   with the localisation mod active so map labels (country
   names) render through Render3d; a crash at VA 0x2054ceb
   before the fix / clean render after it discriminates.
3. Optionally EU4DLL_GLYPH_DEBUG=1 to confirm lookup hits are
   recorded for the tutorial characters (only the three item 31
   code points are logged).

## Unknowns / not verified

- Which exact code point faulted first in the crash run is not
  recorded (glyph debug was off, and it logs only three code
  points anyway). The mechanism does not depend on it: every
  id >= 0x100 takes the same path and faults at id+0xC.
- Whether further latent issues sit behind this one in the
  tutorial-text path (e.g. other CInstantTextBox measuring
  helpers that read the string without going through a hooked
  fetch) can only be told by re-running after the fix; the
  inventory above found no other unhooked CBitmapFont fetch
  site.
- The fix's stack arithmetic is derived from the hook sources
  and the function prologues, not from a patched run; the
  follow-up implementation should re-verify RSP alignment the
  same way the earlier steps did (the /bin/true preload check
  does not cover this - only a real run does).
