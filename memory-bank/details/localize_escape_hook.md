# Localisation-load escape hook: LocalizeYmlAddKey entry hook

Recorded 2026-11-21. Implements the hook recommended by
`localisation_load_conversion_survey.md`: at `LocalizeYmlAddKey`
entry, while the key and value are still UTF-8, escape-encode a
non-ASCII value with `plugin.localization.escape_codec` and store
it through `SLanguageData::AddKeyValuePair` directly, so the
game's `ConvertUTF8ToLatin1` never turns the Japanese characters
into '?'. Opt-in: the hook is installed only for v1_37_5 with
`EU4DLL_LOCALIZE_ESCAPE=1`. Code:
`source/plugin/localization/localize_escape_hook.d`, wired into
`dllmain.d` after `ReloadTrace` / `SetTextHook` init (their
behaviour is unchanged).

## Disassembly facts (eu4 Linux v1.37.5, not stripped)

`LocalizeYmlAddKey` (VA 0x23671a1, size 309,
`_Z17LocalizeYmlAddKeyRK11CUTF8StringS1_iiPv`):
`(const CUTF8String& key /*rdi*/, const CUTF8String& value /*rsi*/,
int arg3 /*edx*/, int arg4 /*ecx*/, void* ctx /*r8*/) -> void`.
The prologue saves r8 to rbx (ctx) and edx to r14d (arg3); arg4
(ecx) is never saved and is not forwarded anywhere - both
AddKeyValuePair paths below build their arguments without it.

### CUTF8String layout

- `+0x00`: `const char*` data pointer. YmlAddKey passes `*(key)`
  and `*(value)` straight to `ConvertUTF8ToLatin1(const char*, ...)`.
- `+0x08`: `int` byte length (signed). Proven from the class's own
  code, not from YmlAddKey (which never reads it):
  `CUTF8String::GetLastLetter` (0x255108a) loads `0x8(%rdi)` as a
  count and walks data bytes back from `data[length-1]` over UTF-8
  continuation bytes; `CUTF8String::CLetter::Get` (0x2550dc0)
  computes `data + index` after comparing the index against the
  `+8` field of the string. The hook reads both fields and
  validates the length (0..1 MiB) before slicing.

### The conversion flag read

At entry+0x16 (0x23671b7): `48 8b 05 d2 f1 0c 01`
`mov 0x10cf1d2(%rip), %rax` - loads the pointer stored in the
global `pData` (the global variable itself is at
0x23671be + 0x10cf1d2 = 0x3436390). At entry+0x1d (0x23671be):
`80 78 38 00` `cmpb $0x0, 0x38(%rax)`, then `je` to the flag-clear
block at entry+0xc1 (0x2367262). So the flag is the byte at
`(*pData) + 0x38`, read on every call. The hook derives the
global's address from the rip-relative displacement at run time
(verifying both instruction byte sequences first) and likewise
dereferences the global on every call; no absolute address is
compiled in.

### AddKeyValuePair call (converting branch)

`SLanguageData::AddKeyValuePair` (0x236b7f8,
`_ZN13SLanguageData15AddKeyValuePairEPKcS1_iib`):
`(SLanguageData* this, const char* key, const char* value,
int, int, bool)`. The call at 0x2367252 (entry+0xb1) builds:

| Register | Source in YmlAddKey | Meaning |
|---|---|---|
| rdi | `mov 0x10(%rbx), %rdi` (0x236723a) | SLanguageData* at ctx+0x10 |
| rsi | `mov $0x34363a0, %esi` | converted key buffer (hook: ASCII key bytes) |
| rdx | `mov $0x34383a0, %edx` | converted value buffer (hook: escaped bytes) |
| ecx | `mov (%rbx), %ecx` (0x236723e) | int at ctx+0 |
| r8d | `mov %r14d, %r8d` (0x236724f) | YmlAddKey's arg3 (entry edx) |
| r9d | `movzbl 0x4(%rbx), %r9d` (0x2367240) | bool byte at ctx+4 |

The flag-clear block (0x2367262) builds the identical registers
(rsi/rdx = the raw CUTF8String data pointers) and tail-jumps to
the same target at entry+0xe0 (0x2367281, `jmp 236b7f8`).

The hook derives AddKeyValuePair's address from the call's E8
rel32 at entry+0xb1 (after checking the `45 89 f0` mov at
entry+0xae) and requires the tail jump's E9 rel32 at entry+0xe0
to resolve to the same address; any mismatch aborts installation.
Both derivations, and the pData one, are pure functions pinned by
unittests against the real instruction bytes (expected results:
pData global 0x3436390, AddKeyValuePair 0x236b7f8).

## Hook mechanics

Reload-trace form, because the copied prefix is only 10 bytes
(push rbp/r15/r14/rbx + `sub rsp, 0x28`, complete instructions
per the survey) and cannot hold the 14-byte absolute jump: the
entry patch is a 5-byte relative jump + 5 NOPs into an entry
trampoline allocated with MAP_32BIT near the target
(fitsRel32-checked); the original trampoline copies the 10 bytes
and resumes at entry+10. The entry AOB is the survey's 16-byte
sequence and installation requires count == 1.

## Decision (pure, unit-tested)

`planLocalizeStore(keyBytes, valueBytes)`:

- key not pure ASCII -> delegate (reason `non-ascii-key`);
- value pure ASCII (including empty) -> delegate (`ascii-value`),
  so ASCII pairs keep the original path with its notification
  lambda and all other side effects;
- value has non-ASCII bytes: `encodeUtf8ToEscaped` failure
  (invalid UTF-8 or above-BMP) -> delegate (`unencodable-value`);
  success -> store escaped.

Flag clear and unreadable inputs (null ctx, bad CUTF8String
length) also delegate, before the decision runs. A reentrancy
guard delegates nested calls. When storing, the hook calls
AddKeyValuePair with the register set tabulated above; the key
buffer is the key bytes as-is (pure ASCII at this point) and the
value buffer is the escaped bytes, both NUL-terminated copies
owned by the call.

Logging: one line at installation (target / derived addresses),
one line on the first direct store (key and lengths), and one
line per delegate reason the first time it occurs. Nothing is
logged per key after that.

## Verification

- `make test`: 11 modules passed unittests (new module included:
  decision cases - pure ASCII, Japanese only, mixed, above-BMP,
  empty, non-ASCII key - plus both address derivations against
  the real bytes and their failure modes).
- `make all` run last, so the normal build is in place.
- No smoke run, per the task instructions: the end-to-end check
  (escaped values stored by this hook rendering through the
  always-on decode hooks) is still outstanding, as are the
  survey's open unknowns - AddKeyValuePair-side truncation or
  validation was not traced, and storing is per-value GC
  allocation in the callback, acceptable for an opt-in first
  version but worth revisiting before default-on.


## Real-machine verification (2026-11-21): hook works, game crashes later in an unhooked measure path

Run runs/20261121-213554-multiplayer: throwaway mod with all 145
placed localisation files plus the 32 item 23 font files,
EU4DLL_LOCALIZE_ESCAPE=1, decode at its default. Throwaway mod
removed afterwards, user folder restored.

- Hook installed at the surveyed addresses (target=0x23671a1,
  addKeyValuePair=0x236b7f8, pDataGlobal=0x3436390). Delegation for
  ASCII values logged, and the first direct store of an escaped
  value logged (key=l_french). So the load-side conversion bypass
  itself works: escaped values reach the dictionary.
- The game then crashed with SIGSEGV at 21:36:21, before the main
  menu (all run screenshots are black). eu4_wait=11, minidump in
  crashes/eu4_20261121_213621.
- Crash stack (exception.txt): CBitmapFont::GetHeightOfString
  (+0x1df, 0x2053d67) <- CInstantTextBox::UpdateScrollbarSize <-
  CTutorialExtraPage::AddText <- CTutorial::Init <-
  CFrontEnd::RestoreDeviceObjects. The tutorial text is localisation
  text, now stored escape-encoded by this hook, and
  GetHeightOfString is a measuring path the decode hooks of items
  17-19/29 do not cover (they cover the RenderToTexture and
  GetRequiredSize fetch sites). The working hypothesis is that this
  measure loop mishandles escape bytes (lead byte 0x10-0x13) and
  reads out of bounds; it is not yet disassembly-proven.
- Next step: survey GetHeightOfString (and sibling measure paths)
  for the same fetch-loop shape as the already-hooked sites and
  extend decode coverage there. Until then EU4DLL_LOCALIZE_ESCAPE
  stays opt-in and must not be enabled for real play.


## Verification of the wide-path fix (2026-11-21)

Run runs/20261121-214814-multiplayer on branch
work/decode-widepath-fix (commit c99d6ed): same setup as the crashed
run (throwaway mod with all 145 localisation files + 32 fonts,
EU4DLL_LOCALIZE_ESCAPE=1, decode default). Throwaway mod removed
afterwards, user folder restored.

- No crash: menu and multiplayer screens reached, eu4_wait=0. The
  tutorial initialisation that segfaulted in GetHeightOfString now
  passes, so the wide-path fix works on the path that crashed.
- The Game Browser now renders Japanese across the screen instead of
  '?': search boxes, the Search button, the server-name / tag /
  status column headers, and the Back button all show the translated
  text (screenshot shot_multiplayer2.png in the run directory).
- Known imperfections, not blockers: some checkbox labels overlap
  the following label (Japanese text is wider than the English
  layout), and two narrow column headers truncate to an ellipsis.
  Width/layout quality is a separate follow-up.
- Not yet verified: the Render3d site 2 wide path (map name labels
  in game) received the same fix in c99d6ed but has not been
  exercised on the real machine.
