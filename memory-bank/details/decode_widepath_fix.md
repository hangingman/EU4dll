# Wide-path glyph result discarded in two fetch hooks: fix

Recorded 2026-11-21. Follow-up to
`getheightofstring_decode_survey.md`, whose patch plan this change
implements unchanged. Branch `work/decode-widepath-fix` (from
`work/localize-escape-hook`).

## Bug (as surveyed)

In `mainTextGetHeightV137_hook` (fetch VA 0x2053d56) and
`mainTextRender3dV137Site2_hook` (fetch VA 0x2054cd0) the glyph
register is RAX itself. The wide path pushed RAX (the decoded code
point id) before calling `wideGlyphLookup` and popped RAX after
the call without copying the result anywhere, so the final
`pop RAX` overwrote the glyph pointer with the id. JMP_H then
tested the id (never null), and the game dereferenced `id + 0xC`
(GetHeight: `movswl 0xc(%rax)` at VA 0x2053d67, the recorded
SIGSEGV of the 2026-11-21 localisation-escape run) or the
equivalent Render3d site 2 reads at VA 0x2054ceb. A lookup miss
was broken the same way: the null result was overwritten, so the
game's own null-glyph path was never taken from the wide path.

## Fix (both hooks, identical edit)

Mirror the proven Proc1 site B shape: RAX is never pushed around
the lookup call. The id in EAX is consumed by `mov ESI, EAX`
before the call, so no saved copy is needed.

- Removed `push RAX;` at JMP_G entry and the matching
  `pop RAX;` in the epilogue. Pushes are now RCX, RDX, RDI.
- Stack adjustment: `sub RSP, 48` -> `sub RSP, 40`, and the
  matching `add RSP, 48` -> `add RSP, 40`. Total adjustment
  4*8+48 = 80 -> 3*8+40 = 64, still 0 mod 16, so the call-site
  alignment is unchanged (GetHeight fetch point has
  RSP % 16 == 0: prologue 6 pushes + sub 0xB8). XMM spill
  offsets inside the sub area (XMM0-XMM5, plus XMM10 at +24 in
  Render3d site 2) do not move.
- After the fix, `test RAX, RAX` at JMP_H tests the real lookup
  result: a hit returns the glyph pointer to the game's
  continuation (0x2053d67 / 0x2054ce1), a miss takes the hook's
  null return (0x2053dfc / 0x205519d), the game's own null-glyph
  path - the same semantics the embedded fetch had.
- No AOB, patch length (14 bytes), return address, index
  advance, or decode-constant changes. The Proc4 injector
  installs both hooks unchanged. Header comments of both hooks
  now state that RAX is never pushed.

## Re-check of every other push/pop RAX site (grep inventory)

All `push RAX;` sites in source/plugin/main_text.d and
source/plugin/font.d were re-inspected for the same pattern
(lookup result landing in RAX with no copy-out before the pop,
and the continuation testing RAX):

| Site | Result handling | State |
|---|---|---|
| Proc1 site A | `mov R15, RAX` after call | safe |
| Proc4 GetActual / GetRequired / GetActualReal | `mov RBP, RAX` | safe |
| BitmapWidth (GetWidthOfString) | `mov RBP, RAX` | safe |
| RenderToScreen site 1 / site 2 | `mov RBP, RAX` / `mov R13, RAX` | safe |
| RenderToTexture site 1 / site 2 | inner push/pop pair only guards the raw-log call (its result is discarded on purpose, id restored for `mov ESI, EAX`); lookup result copied with `mov RBP, RAX` / `mov R11, RAX` before the outer pops; JMP_H tests RBP / R11 | safe |
| Render3d site 1 | `mov RBX, RAX` after call | safe |
| Proc1 site B | RAX never pushed (RCX/RDX only) | safe (the model for this fix) |
| font.d glyphDuplicateCheck_hook | `mov R11, RAX`, tests R11 | safe |
| font.d glyphStore_hook | call result unused by design; `pop RAX` restores the entry glyph pointer (an input, passed to the register call in RDX) | safe |
| **GetHeightOfString** | **no copy-out, JMP_H tested RAX** | **fixed here** |
| **Render3d site 2** | **no copy-out, JMP_H tested RAX** | **fixed here** |

No other site has the pattern.

## Verification

- `make test`: 11 modules passed unittests. `make all` run last
  (normal build in place, libeu4dll.so md5
  e2bfd99fe75344c6fe2bf5ab81042705).
- No smoke run in this change (per task split). The survey's
  verification plan stands: rerun the localisation-escape
  multiplayer run (CTutorial::Init exercises GetHeightOfString
  before the menu), then exercise Render3d site 2 with map
  labels under the localisation mod. Only a real run
  re-verifies the stack alignment end to end.
