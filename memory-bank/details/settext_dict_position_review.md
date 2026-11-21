# SetText dictionary: position review against the localisation-load hook

Recorded 2026-11-21. Read-only survey for the owner's TODO item
"SetText辞書の位置づけ見直し" (reconsider the position of the SetText
dictionary). No code was changed. Code state surveyed: the working
tree of `work/memory-bank-cleanup`; the four files involved
(`source/plugin/mod.d`, `source/plugin/localization/settext_hook.d`,
`source/plugin/dllmain.d`, `tests/plugin/test_mod.d`) are identical
to master. On this branch the localisation-load hook is already
enabled by default (commit 5b8acc7, `EU4DLL_LOCALIZE_ESCAPE=0` opts
out), which is the "normal play" configuration this review assumes.

## 1. How the dictionary is wired today (facts)

### Initialisation order (dllmain.d, hijackProcess)

1. `loadTranslationMods()` runs first (unless
   `EU4DLL_SKIP_TRANSLATIONS=1`). It scans every `*.yml` under
   `~/.local/share/Paradox Interactive/Europa Universalis IV/mod`
   recursively — every mod folder found there, not only translation
   mods — and fills the global `translationMap` (key -> Japanese
   text). This predates the dictionary and also feeds
   `logTranslationObservations()` and the `PluginVersion.init` log
   line, so it stays regardless of what happens to the dictionary.
2. `SetTextHook.initSetTextHook(eu4Version)` runs next, before
   `LocalizeEscape.initLocalizeEscapeHook(eu4Version)`.

### Activation conditions (settext_hook.d, initSetTextHook)

The hook as a whole installs only when **both**:

- the game version is v1.37.5, and
- `EU4DLL_SETTEXT_PROBE` is exactly `"1"`.

Inside that gate, `loadSetTextMappings()` picks the mapping source:

- `EU4DLL_SETTEXT_REPLACEMENTS` non-empty -> the hand-written env
  probe wins; the file dictionary is not read at all (`source=env`).
- else `EU4DLL_SETTEXT_FROM_TRANSLATIONS` == `"1"` -> dictionary
  mode (`dictMode = true`, `loadTranslationDictMappings()`).
- else -> probe path with zero mappings; the hook then refuses to
  install ("SetText probe disabled: no valid mappings").

So the dictionary needs `EU4DLL_SETTEXT_PROBE=1` **and**
`EU4DLL_SETTEXT_FROM_TRANSLATIONS=1` **and**
`EU4DLL_SETTEXT_REPLACEMENTS` unset. It is off by default in every
configuration.

### Dictionary build (loadTranslationDictMappings)

- English side: `loadLocalisationMap(gameLocalisationDir())` parses
  every `*.yml` under the game's own `localisation` folder
  (`EU4DLL_GAME_LOCALISATION_DIR` overrides the folder).
- Japanese side: `translationMap` rebuilt as key -> value.
- `joinTranslationDictionary` inverts both through the localisation
  key into English text -> Japanese text. One English string with
  conflicting Japanese values is dropped whole (`ambiguous`); equal
  pairs collapse (`deduplicated`).
- Each joined entry goes through `buildDictMapping`: source empty or
  over 256 bytes, empty target, unencodable target, or prepared
  (escape-encoded) bytes over 256 bytes are skipped per reason.
- Storage is a `ProbeMapping[]` plus an associative array from the
  exact English source bytes to the mapping index.

### Runtime path

The hook patches `CTextSprite::SetText` (v1.37.5, VA 0x20d9da4) and
inspects only the first CString argument (rdx; the log line itself
says the trailing ABI is unverified). `tryReplaceDict` reads the
CString header and bytes, requires length 1..256, looks the **whole
value up by exact byte match** (`findDictMapping`), then applies the
same capacity check and write procedure as the probe path: the
replacement must fit the CString's existing capacity (SSO capacity
is 15), otherwise the call is skipped as `exceeds-capacity`.

Measured on the real game (run runs/20261121-212246-multiplayer,
recorded in `translation_dict_stage_b.md`): japanese-keys=125959,
english-keys=55090, joined=46845, deduplicated=6787, ambiguous=491,
loaded=42886, skipped-source-length=3003,
skipped-replacement-length=953, skipped-empty-replacement=3,
skipped-unencodable=0 — and exactly **one** replacement was applied
during that run.

## 2. What role is left when the load hook is on

The load hook (`localize_escape_hook.d`) intercepts
`LocalizeYmlAddKey`: for a non-ASCII value it stores the
escape-encoded value directly through `SLanguageData::AddKeyValuePair`,
so the game's dictionary holds the translation in escaped form, per
key. Pure-ASCII values delegate to the original conversion.

### (a) Strings the load hook cannot reach

The dictionary can only fire on a string that arrives at SetText as
the **complete, unmodified English display text** of some
localisation entry, because the lookup is an exact match on the
whole CString. That excludes, by construction:

- every string the game resolved from yml localisation when the
  translation mod is enabled — those arrive escape-encoded (load
  hook on) or '?'-mangled (load hook off; stage B finding), never
  as English;
- dynamically assembled strings: any value with substituted
  numbers, dates, names or other variables differs from the stored
  English template, so it cannot match;
- strings over 256 bytes (rejected at the header check) and, in
  practice, most shorter ones too, because the replacement must fit
  the CString's existing capacity — the stage B record already
  notes most entries end as `exceeds-capacity`, and the one real
  run applied a single replacement.

What remains is English text that never passes through
`LocalizeYmlAddKey` at all: hard-coded strings in the binary or in
`.gui` files, and similar non-yml sources. How much of what players
see that is, has never been measured (see open questions). It is a
residual category, not a coverage layer.

### (b) Translating with environment variables only, no mod

Mechanically this works: the DLL scans the mod folder on disk
itself, so `translationMap` is built whether or not the game
enables the mod, and the English side comes from the game's own
files. With the mod disabled in the launcher, the game holds
English, SetText receives English, and the dictionary can replace
it — this is the one configuration where the dictionary is the
only translation path.

In practice the configuration is undermined by the fonts. The
generated Japanese fonts ship inside the same mod
(`gfx/fonts`, shadowing the base font names: Arial12, garamond_*,
standard_*, vic_*) and the game only loads them from an enabled
mod. Without the mod, the escaped Japanese the dictionary writes
has no glyphs to render with. So "env vars only" still needs the
mod enabled for fonts — and once the mod is enabled, the load
hook covers the localisation itself. (Font loading from enabled
mods is standard game behaviour and matches how every
verification run was set up; it was not re-proven for this review.)

### (c) Interference when both are active

None found, by construction. A value stored by the load hook
begins its non-ASCII runs with the escape lead bytes 0x10..0x13
(`escape_codec.d`, ESCAPE_SEQ_1..4); dictionary keys are plain
English text. An exact byte match between an escaped value and an
English key is impossible. The only values that can match are
pure-ASCII ones, which the load hook deliberately delegates and
leaves in English — replacing those is the dictionary's intended
behaviour, not double application. The dictionary's own
replacement is escape-encoded exactly once
(`prepareSetTextReplacement`, shared with the probe path), so a
fired replacement cannot be re-encoded by a second pass either:
after replacement the CString no longer holds the English source.

### (d) Maintenance and startup cost

Startup cost is opt-in only: with the dictionary off (the default)
nothing in this section runs. When on, the build parses the game's
whole localisation folder (55,090 keys measured) and prepares
42,886 mappings. No isolated timing for the dictionary build
exists in the records. Bounds from the verification run's log
timestamps: `loadTranslationMods` (not dictionary-specific, runs
either way) took ~5.1 s for 145 files / 125,959 entries
(21:22:46.454 -> 21:22:51.591), and the dictionary load line is
stamped 21:23:07.193, so the window containing the game-localisation
parse, the join and the mapping build — plus other initialisers
that run in between — is ~15.6 s at most.

Code kept alive for the dictionary: in `settext_hook.d`, the
`dictMode` storage (dynamic mappings, index AA, three parallel
once-log arrays), `loadTranslationDictMappings`, `buildDictMapping`,
`findDictMapping`, `tryReplaceDict`, the dictionary branch of
`loadSetTextMappings` and of `setTextProbe`; in `mod.d`,
`loadLocalisationMap`, `gameLocalisationDir`,
`joinTranslationDictionary` and the `TranslationJoinResult` /
`TranslationJoinStats` structs. A grep over `source/` and `tests/`
confirms the only caller of the three `mod.d` helpers is the
dictionary loader. There is also a standing confusion cost: three
environment variables interact, and `EU4DLL_SETTEXT_REPLACEMENTS`
silently overrides `EU4DLL_SETTEXT_FROM_TRANSLATIONS`.

## 3. Recommendation: fold the dictionary (畳む)

Remove the file-dictionary path; keep the SetText hook itself and
the env-var probe.

Reasons:

1. The load hook covers the dictionary's original target —
   yml localisation — completely and per key. It has none of the
   dictionary's structural limits: no 256-byte ceiling, no CString
   capacity check, no `ambiguous` drops (491 English strings lost
   their translation in the measured build because two keys
   disagreed; the load hook never has to choose, since the game
   resolves by key).
2. The measured effect is negligible: one replacement applied in
   the dictionary's own verification run, and the stage B record
   already concluded its coverage shrinks exactly when the
   translation mod is in use.
3. Its one unique configuration — translation without enabling
   the mod — is blocked in practice by the fonts living in the
   same mod (section 2b).
4. It is not a fallback for the load hook: both paths are locked
   to v1.37.5 patterns, so a game update breaks them together.
5. Keeping it costs a second translation mechanism to reason
   about, ~400 lines across two modules plus their tests, and a
   three-variable activation matrix with a silent override.

The SetText hook and the `EU4DLL_SETTEXT_REPLACEMENTS` probe are a
different matter: they are the diagnostic instrument items 1-6 were
verified with, and `eu4_smoke.sh` still greps for the probe's
`SetText replacement applied` marker. They stay.

### Removal scope, if the owner folds it

- `source/plugin/localization/settext_hook.d`: `dictMode`,
  `dictMappings`, `dictIndexBySource`, the three `dict*Logged`
  arrays, `loadTranslationDictMappings`, `buildDictMapping`,
  `findDictMapping`, `tryReplaceDict`, the
  `EU4DLL_SETTEXT_FROM_TRANSLATIONS` branch in
  `loadSetTextMappings` (probe-only afterwards), the dictionary
  branch in `setTextProbe`, the `plugin.mod` import of the three
  helpers, and the dictionary unittest blocks
  (`buildDictMapping` / `findDictMapping` asserts).
- `source/plugin/mod.d`: `loadLocalisationMap`,
  `gameLocalisationDir`, `joinTranslationDictionary`,
  `TranslationJoinResult`, `TranslationJoinStats`.
  `parseLocalisationFile`, `loadTranslationMods` and
  `translationMap` stay (they predate the dictionary and are used
  by `plugin_version.d` and the translation observations).
- Environment variables retired: `EU4DLL_SETTEXT_FROM_TRANSLATIONS`,
  `EU4DLL_GAME_LOCALISATION_DIR`. `EU4DLL_SETTEXT_PROBE` and
  `EU4DLL_SETTEXT_REPLACEMENTS` stay.
- Tests: the `loadLocalisationMap` / `joinTranslationDictionary` /
  `EU4DLL_GAME_LOCALISATION_DIR` cases in `tests/plugin/test_mod.d`.
- Records: `translation_dict_stage_b.md` and
  `translation_file_loading_design.md` stay as history; the removal
  itself gets a progress.md entry and a short detail record when
  it is done.

## 4. Open questions

- No run has ever counted how many strings reach SetText in
  English form from non-yml sources during real play, so the
  residual coverage in section 2a is unquantified. Measuring it
  would need a dictionary-mode run with the load hook on and a
  count of applied replacements.
- The dictionary build has no isolated startup timing; only the
  ~15.6 s upper-bound window above.
- Whether escaped Japanese renders acceptably when the fonts are
  supplied without enabling the mod (e.g. copied into the game's
  own `gfx/fonts`) was not tested; section 2b's conclusion follows
  the shipped file layout.
