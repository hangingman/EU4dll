# Localisation load conversion point: survey

Recorded 2026-11-21. Read-only investigation: no game or DLL code was
changed. Question (from the stage B Finding in
`translation_dict_stage_b.md`): where does the game's own localisation
load turn UTF-8 yml text into game-internal text, replacing every
Japanese character with one '?'? That point is the hook candidate for
escape-encoding Japanese at load time (the "Localisation-load
injection" alternative in `translation_file_loading_design.md`).

## Answer in one line

The conversion point is identified: `LocalizeYmlAddKey`
(0x23671a1) converts each key and value with
`ConvertUTF8ToLatin1` (wrapper 0x254d8a1, core 0x254d531) right
before storing them via `SLanguageData::AddKeyValuePair`
(0x236b7f8). Inside the core converter, any character that has no
single-byte mapping is left as the byte 0x3F ('?') it writes into the
output buffer before it even tries to decode the sequence. Japanese
(3-byte UTF-8) has no entry in its small fixed tables, so every
Japanese character becomes exactly one '?' - which matches the
real-machine observation (counts match, "??" for a 2-character word).

## Why this was findable at all

The shipped Linux binary is **not stripped and carries debug_info**
(60,526,352 bytes, GNU/Linux x86-64). Function symbols give the whole
call graph below; direct `call rel32` targets were verified by
scanning `.text` for E8 encodings and resolving them against the
symbol table. The Ghidra project was not needed and was not touched.
All VAs are the binary's own (non-PIE executable), i.e. the same
address space the DLL's BytePattern search resolves at runtime;
cross-check: the symbol `ReloadPdxLocalize` sits at 0x1fefa3a and
its first call goes to `LocalizeGetCurrentLanguage` (0x2365cc1),
exactly the rel32 (0x37627A) embedded in the pattern in
`source/plugin/localization/reload_trace.d`.

## The load path (initial load and reload share the conversion)

Initial load:

```
PdxLocalizeInitialize            0x1fef2e8
  -> ReadLocalizationFileHelper  0x1fef1ce   (also reached via
     ReadLocalizationFolderHelper 0x1fef56c <- PdxLocalizeReadFolder 0x1fef629)
  -> LocalizeAddLocalizationYAMLBuffer 0x236785b
  -> YmlParse                    0x2366224   (call at 0x236795f)
  -> callback LocalizeYmlAddKey  0x23671a1   (passed in r8 at 0x2367956;
                                              language callback is
                                              LocalizeYmlAddLanguage 0x2367108 in rcx)
  -> ConvertUTF8ToLatin1         0x254d8a1 -> core 0x254d531
  -> SLanguageData::AddKeyValuePair 0x236b7f8
```

Reload path (for completeness; same tail): `ReloadPdxLocalize`
0x1fefa3a -> `ReloadPdxLocalizeHelper` 0x1fef96e ->
`PdxLocalizeReadFolder` 0x1fef629 -> folder/file helpers -> same
YAMLBuffer/YmlParse/YmlAddKey chain. So one hook at the tail covers
both the initial load and reloads. This does not contradict the
older judgement that `ReloadPdxLocalize` is not a display-update
point: the hook target is not the reload entry, it is the per-key
conversion both paths funnel through.

## LocalizeYmlAddKey anatomy (0x23671a1)

Signature: `LocalizeYmlAddKey(CUTF8String const& key,
CUTF8String const& value, int, int, void*)` - both strings still
UTF-8 here.

- It first tests a byte flag at `pData + 0x38` (pData = 0x3436390).
  - Flag set (the branch the real run takes, proven by the '?'
    output): the key is converted into a static buffer at
    0x34363a0 (call at 0x23671de) and the value into a static buffer
    at 0x34383a0 (call at 0x236721c), both via
    `ConvertUTF8ToLatin1(const char*, char*, const std::function<void(const char*)>&)`.
    The std::function is a per-call lambda
    (`LocalizeYmlAddKey::$_0`, invoke 0x236b220); if the converter
    leaves a callable in it, YmlAddKey invokes it with argument 3
    after each conversion (the converter's "couldn't convert"
    notification path, see below). Then
    `AddKeyValuePair(keyBuf, valueBuf, ...)` at 0x2367252 stores the
    converted pair.
  - Flag clear: it tail-jumps to `AddKeyValuePair` with the raw
    UTF-8 strings unconverted (0x2367262-0x2367281).
- The exact meaning of the `pData + 0x38` flag was not identified
  (name not recovered). What is proven is only that the converting
  branch is the one taken when the mod's `l_english` files load:
  unconverted storage would show raw UTF-8 bytes downstream, not
  one '?' per character.

## Inside ConvertUTF8ToLatin1 (core 0x254d531)

Signature: `ConvertUTF8ToLatin1(const char* in, int inLen, char* out,
int outLen, const std::function<void(const char*)>&)`. The wrapper
0x254d8a1 is a 16-byte prologue ending in a tail jump to the core
with both lengths = -1.

- 0x254d5ac: ASCII fast path - a byte < 0x80 is copied verbatim.
- 0x254d5bd: for any non-ASCII lead byte it **first writes 0x3F
  ('?') to the output**, then counts the sequence length from the
  lead byte's set bits (the `test $0x20` loop at 0x254d5cb-0x254d5e1).
- Length 2 (0x254d66b): the 2-byte sequence is looked up in a sorted
  table (`pdx::binary_find` over S2Byte/S2UTF8 entries,
  0x34475e0-0x3447745); a hit replaces the '?' with the mapped
  single byte (Latin-1 range and a few Latin Extended foldings,
  e.g. sequences visible in .rodata: C3 B6 -> F6, C4 98 -> 45).
  A miss leaves 0x3F and, at 0x254d6b5-0x254d6e5, builds the
  notification message beginning "Couldn't find Latin1 character
  for " (string at 0x28b7ce5) for the callback.
- Length 3 (0x254d631): the 3-byte sequence is compared against a
  small fixed table of 4-byte entries (3 UTF-8 bytes + 1 replacement
  byte) scanned at 0x254d63b-0x254d661. Only a handful of special
  characters are in it; no CJK is, so kana/kanji keep the
  pre-written 0x3F.
- Length 4 or malformed input: also leaves 0x3F (and can invoke the
  callback with "Attempted to read more bytes than input size",
  string at 0x28b7cb8, on truncation).

So the '?' substitution is not a font or rendering effect: the
stored dictionary value itself is already '?'-only for Japanese.

## Hook candidates

| # | Point | VA | What you see there | Entry bytes / AOB (count in .text) | Assessment |
|---|-------|----|--------------------|------------------------------------|------------|
| 1 | `LocalizeYmlAddKey` entry | 0x23671a1 | key + value as UTF-8 CUTF8String, before any conversion | `55 41 57 41 56 53 48 83 EC 28 4C 89 C3 41 89 D6` - unique (1) | **Most promising.** A hook can escape-encode the value itself and call `AddKeyValuePair` (0x236b7f8) directly, skipping the Latin1 conversion entirely. Prologue is 10 bytes of complete instructions (push x5 + sub rsp,0x28) before the first rip-relative load, so a copied-prefix trampoline in the reload_trace style needs a 10-byte prefix, not 8. Keys are ASCII in practice, so key handling can mirror the original (convert or pass through). Must reproduce the pData+0x38 branch decision or simply always store the escaped pair - see unknowns. |
| 2 | `ConvertUTF8ToLatin1` wrapper | 0x254d8a1 | one UTF-8 string (key or value), output buffer pointer | `49 89 D0 48 89 F2 BE FF FF FF FF B9 FF FF FF FF` - unique (1) | Close second. Its only callers outside the overload family are the two YmlAddKey sites, so replacing it affects localisation only. Simpler signature (char* in/out) than #1, but the hook sees key and value indistinguishable, and the output goes to the fixed 0x2000-byte static buffers; escaped CJK is 3 bytes/char, the same as UTF-8 CJK, so length does not grow for Japanese. The entry is 16 bytes of complete instructions followed by the tail `jmp`, so an absolute-jump patch fits cleanly. |
| 3 | Convert call sites in YmlAddKey | 0x23671de (key), 0x236721c (value) | same as #2, per-string | each is a single E8 rel32 | Workable but strictly worse than #1/#2: two patch points, and the value site sits after the callback plumbing. Listed for completeness. |
| 4 | `ConvertUTF8ToLatin1` core | 0x254d531 | every UTF-8->Latin1 conversion in the process | prologue `55 41 57 41 56 41 55 41 54 53 48 81 EC B8 01 00 00` - **not** unique (109) | Avoid. Shared with non-localisation callers (CAchievement name/description, CCreditsScreen::Initialize, CKeyEvent::GetNameFromKeyEvent, POPS social callback), so a behaviour change here leaks outside localisation, and the prologue AOB is unusable anyway. |
| 5 | `SLanguageData::AddKeyValuePair` entry | 0x236b7f8 | key + value as single-byte char* | prologue 16B - not unique (19) | Too late to be a conversion hook (value is already '?'-substituted), but it is the sink a #1 hook must call with the escaped bytes, so its address is recorded here. AOB would need extending past the prologue if it ever has to be found by pattern. |

## Recommendation

Hook `LocalizeYmlAddKey` (candidate 1). It is the last point where
the value is still complete UTF-8, it funnels both the initial load
and reloads, its entry AOB is unique, and the escape encoder plus
dictionary machinery from stage B carry over unchanged: instead of
letting the original convert the value to Latin1, encode the UTF-8
value with `escape_codec` and pass the escaped bytes to
`AddKeyValuePair`. Candidate 2 is the fallback if CUTF8String
handling in a hook proves awkward.

## Unknowns / not verified

- Meaning of the `pData + 0x38` flag that selects the converting
  branch. Behaviour proves the branch is taken for the mod load,
  but a #1 hook must decide whether to honour the flag (pass raw
  UTF-8 through when clear, as the original does) - honouring it is
  the conservative choice and needs the flag read, not a name.
- Whether `AddKeyValuePair` / the dictionary storage truncates or
  validates values (length limits, byte filters). Not traced past
  the call; a hook prototype should store one known escaped value
  and read it back via the dictionary before wider claims.
- Whether escaped bytes survive the later lookup/render path
  unchanged is assumed, not proven here: `LocalizeString`
  (0x23677f0) and friends treat values as single-byte strings, and
  the escape bytes (0x10-0x13 plus shifted code bytes) are ordinary
  single bytes for byte-wise copies, but no end-to-end run with an
  escaped dictionary value has been done. That is the next
  verification, together with the decode hooks that are now on by
  default.
- The callback lambda's exact side effect (logging only, most
  likely) was not traced; it does not affect the conversion result.
