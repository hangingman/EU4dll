# Migrating SetText replacements from the env-var probe to translation files: design

Recorded 2026-11-21 (item 7). Design only: no implementation was
changed in this item. Large rework waits for the owner's confirmation,
per the task instruction.

## Purpose and scope

Today the SetText hook is fed by a hand-written environment variable.
That was right for a probe (items 1-6), but it cannot scale to a real
translation: the operator would have to type every source/target pair
by hand, in the game's display encoding, on every launch. This design
records how to move the source of the mappings to translation files
(yml), what has to exist before that move can display Japanese, and
where the owner's decisions are still needed.

Out of scope for the migration itself: enabling the double-byte
decode hooks, writing the UTF-8-to-escape encoder, and initialising
the `EU4JPModAppendixI` submodule. Those are prerequisites or
parallel workstreams (see "Prerequisites"), not part of the loader
change.

## Current state (as built, items 1-6)

- `source/plugin/localization/settext_hook.d`:
  `loadProbeMappings()` reads `EU4DLL_SETTEXT_REPLACEMENTS` once at
  hook installation. Format: `Source=Replacement;Source=Replacement`,
  parsed by the pure `parseSetTextProbeEntry`. Limits are
  `MaxMappings = 8` and `MaxProbeBytes = 256` per side; rejections are
  logged per entry (`missing-separator`, `multiple-separators`,
  `empty-source`, `empty-replacement`, `too-long`,
  `too-many-mappings`). A mapping whose replacement exceeds the
  target CString capacity is skipped at match time with
  `reason=exceeds-capacity` (items 4-5); otherwise the replacement
  bytes plus a terminating NUL are written and the length field (+8)
  is updated together.
- `source/plugin/mod.d`: `loadTranslationMods()` already loads yml
  files from the Paradox mod directory
  (`~/.local/share/Paradox Interactive/Europa Universalis IV/mod`)
  into `translationMap` (localisation key -> Japanese value, UTF-8 D
  strings, via `normalizeLocalizationYaml`). It runs from
  `dllmain.d` before `SetTextHook.initSetTextHook`, but the hook
  never consults the map; the map is used only for load-time
  observation logs (`EU4DLL_TRANSLATION_OBSERVATION_KEYS`).
- So the two halves already exist in one process and already run in
  the right order (dictionary load first, hook second). What is
  missing is the join between them, plus the encoding work below.

## Constraints established by items 5 and 6

These are not assumptions; each is recorded in its own document.

1. **No direct key correspondence (item 6,**
   `details/translationmap_settext_correspondence.md`).
   `translationMap` keys are localisation keys (e.g. `BACK`,
   `MENU_BAR_LOAD_GAME`). SetText receives the resolved display text,
   which in an `l_english` session is the English value from the
   game's own `localisation/*_l_english.yml`. A file-based loader
   therefore cannot key replacements by localisation key; it must
   invert through the English value:
   key -> English source text -> Japanese target text.
2. **English values are not unique.** Different keys can share one
   English string. The inverted map can collide; a collision rule is
   required (see "Join algorithm").
3. **Coverage is partial by construction.** `MENU_BAR_LOAD_GAME` ->
   `Load Game` produced no SetText log line at all in a main-menu run
   (item 6). Some keys' English text never reaches this hook, so a
   file loader on this hook cannot promise full coverage, and
   "not observed" must stay distinct from "mismatch" in logs.
4. **Targets must be in escaped form, not UTF-8 (item 5,**
   `details/mojibake_settext.md`). The hook writes replacement bytes
   verbatim and EU4 reads them as single-byte text. Japanese is only
   representable in the DLL's escape scheme (escape byte 0x10-0x13
   plus a two-byte shifted code point per character, decoded in
   `source/plugin/main_text.d`). This repo has **no**
   UTF-8-to-escape encoder today.
5. **The decode side is off on Linux.** `Font.init` and
   `TextView.init` are commented out as TODO in `dllmain.d`, so even
   a correctly escaped replacement would not be decoded on
   Linux v1.37.5 yet. File loading alone does not make Japanese
   display; it only removes the hand-typed dictionary.
6. **Capacity is in escaped bytes.** The item 4/5 capacity check
   compares the replacement byte length against the CString capacity
   (SSO 15 for both measured targets). Escaped Japanese costs 3 bytes
   per character (1 escape + 2 code bytes), so a 15-byte SSO capacity
   holds at most 5 Japanese characters. Most real translations will
   exceed SSO capacity and be skipped as `exceeds-capacity` until a
   proven over-capacity strategy exists; the design must surface
   that as an expected skip, not a silent failure.

## Proposed design

### Overall shape

Keep `tryReplace` and the capacity/logging machinery unchanged. Replace
only the *source* of the `ProbeMapping[MaxMappings]` table:

```
  translation yml (key -> Japanese, UTF-8)  --+
                                               +--> join (pure) --> source(English bytes)
  game English yml (key -> English)         --+         |              -> target(escaped bytes)
                                                          v
  env var EU4DLL_SETTEXT_REPLACEMENTS ------ override -> ProbeMapping table -> tryReplace (unchanged)
```

- The join and the encoder are pure functions with unit tests, in the
  same style as `parseSetTextProbeEntry` / `cstringCapacity` /
  `decideSetTextMapping` today. The hook's runtime path stays
  allocation-light and keeps its per-mapping log formats
  (`formatSetTextReplacementLog`, `formatSetTextCapacityLog`) so
  items 1-6 logs remain comparable after the migration.
- The env-var probe stays available as an explicit override/debug
  path (it is how items 1-6 were verified, and it isolates "loader
  problem" from "hook problem"). Precedence: if
  `EU4DLL_SETTEXT_REPLACEMENTS` is set, it wins and the file path is
  not read; the load log states which source was used. This is a
  proposal for the owner to confirm, not a settled rule.

### Inputs

1. **Target side:** the yml files `loadTranslationMods()` already
   reads (Paradox mod directory). Reuse `translationMap` as-is; do
   not add a second yml parser for the same files.
2. **Source side (new):** the game's English localisation. Options:
   a. Read the game's `localisation/*_l_english.yml` at load time
      with the same `normalizeLocalizationYaml` normalisation.
      Pro: always matches the installed game version. Con: needs a
      reliable path to the game install from the DLL, and parsing
      the full English set is far larger than the mod set.
   b. Ship a small derived source file with the mod (key -> English)
      generated offline. Pro: bounded size, reviewable. Con: can
      drift from the game version.
   The design does not choose between (a) and (b); see "Open
   decisions". Either way the source side is key -> English text,
   never a hand-maintained source->target list.
3. **Generated mod data:** the real Japanese values depend on
   `submodules/EU4JPModAppendixI` (its `main.py`, requiring
   `PARATRANZ_SECRET`), which is uninitialised (item 6). The loader
   design must work with whatever yml is present in the mod
   directory and log an empty dictionary as such (as it already
   does), rather than depending on the submodule being present.

### Join algorithm (pure, unit-tested)

For each key present in both maps:

1. Normalise the English value exactly as the game presents it to
   SetText (no trimming beyond what the yml parser already yields;
   item 6 evidence is byte-exact matches for `Back` and
   `Connect to ID`).
2. Encode the Japanese value to escaped bytes via the encoder
   below. If any character is unencodable, skip the whole entry and
   log it once at load (`reason=unencodable`); never emit a partial
   string.
3. Insert English bytes -> escaped bytes into the mapping table.
   - Collision (same English bytes, same target): deduplicate.
   - Collision (same English bytes, different targets): skip the
     entry and log `reason=ambiguous-source` at load. First-wins is
     rejected here because dictionary order would silently decide
     user-visible text; skipping keeps the failure visible. Owner
     may override this choice.
4. Apply the existing limits as load-time rejections with the
   existing reason vocabulary where possible (`too-long`,
   `too-many-mappings`), so load logs stay comparable.

**Scaling note:** `MaxMappings = 8` and the fixed-size
`ProbeMapping` array are probe-sized. A real dictionary is orders of
magnitude larger, and `tryReplace` currently scans the table on
candidates. Raising the cap is therefore not a constant tweak: the
implementation step must decide a storage/lookup shape (for example
a length-bucketed index, since `decideSetTextMapping` already gates
on length first) and re-measure the per-call cost. That decision is
part of implementation, not of this design record, and is a reason
the migration is staged (see "Staging").

### UTF-8-to-escape encoder (new component, prerequisite)

- Input: a UTF-8 D string from `translationMap`. Output: the byte
  sequence `main_text.d` decodes: for each code point, choose the
  escape byte 0x10-0x13 and the two-byte shifted value using the
  inverse of the decode adjustments (`SHIFT_2 = 0x0E`,
  `SHIFT_3 = 0x900`, `SHIFT_4 = 0x8F2`; plain ASCII/single-byte
  characters pass through unescaped, matching the decode path's
  non-escape branch).
- Code points above the decode side's `NO_FONT` threshold become
  `NOT_DEF` on display; the encoder should log such characters at
  load instead of discovering them on screen.
- The encoder is pure and must be round-trip tested against a test
  double of the decode logic (decode(encode(s)) == s for the
  representable range), plus fixed vectors for ASCII, kana, and a
  kanji in each escape band. It must not be validated only by
  on-screen display, which items 2/5 showed is not reachable for
  every string.
- Byte-length accounting for the capacity check uses the escaped
  length (3 bytes per escaped character), not the character count.

### Configuration (proposed names, not implemented)

- `EU4DLL_SETTEXT_FROM_TRANSLATIONS=1`: opt-in switch for the
  file-based source, mirroring the existing explicit opt-in style
  (`EU4DLL_SETTEXT_PROBE=1`, `EU4DLL_SKIP_TRANSLATIONS=1`). Without
  it, behaviour is exactly as today.
- `EU4DLL_SETTEXT_REPLACEMENTS`: unchanged; when set it overrides
  the file source (see above).
- No new mandatory environment variables. The mod directory and the
  game path, if option (a) is chosen, are derived as
  `loadTranslationMods` already derives the mod directory.

### Logging

- Load time: one line stating the mapping source
  (`env` / `translations` / `none`), counts loaded and skipped per
  reason (including the new `unencodable` and `ambiguous-source`),
  reusing the existing per-mapping `result=loaded/skipped` shape.
- Runtime: unchanged per-mapping applied/skipped/capacity logs.
  A key whose English text never reaches SetText produces no runtime
  line, as in item 6; the design does not add speculative
  "missing" runtime logs.

## Prerequisites (blocking Japanese display, not blocking the loader)

In dependency order:

1. **Encoder** (above). Testable in isolation, no game needed.
2. **Decode side on Linux v1.37.5:** port/enable the `main_text.d`
   text-loop hooks and `font.d` patches (`Font.init` /
   `TextView.init` in `dllmain.d`), with the same AOB-uniqueness and
   instruction-boundary verification the SetText hook required.
   TODO.txt already lists the Ghidra exploration of text processing
   loop 2 as on hold; this is the largest unknown in the whole
   programme and is a separate item from the loader migration.
3. **Real translation data:** submodule initialisation plus
   generation with `PARATRANZ_SECRET` (owner decision, item 6).
   The loader can be built and tested with fixture yml (as
   `tests/plugin/test_mod.d` already does) before this lands.

Until (2) lands, end-to-end verification of the file loader is
limited to: load/join/encode logs, English-to-English fixture pairs
displaying correctly, and Japanese pairs being applied at the hook
(`result=applied`) without any claim about on-screen correctness -
the same evidence standard as items 5 and 6.

## Staging (each stage separately confirmed by the owner)

1. **Stage A - encoder + tests.** No hook change.
2. **Stage B - join + file source behind the opt-in switch,**
   capped at the current table limits, verified with fixture yml
   and the two known strings (`Back`, `Connect to ID`). Env-var
   behaviour unchanged when the switch is off.
3. **Stage C - scaling.** Storage/lookup change for a full
   dictionary, with per-call cost measured on the real game.
4. **Stage D - decode enablement** (prerequisite 2) and only then
   Japanese on-screen verification for strings that actually reach
   SetText.

## Alternatives considered

- **Localisation-load injection instead of SetText:** replacing the
  text where UTF-8 yml becomes game-internal text would avoid the
  English-value inversion. `ReloadPdxLocalize` was already ruled out
  as a display-update point (it rebuilds the dictionary without
  refreshing generated UI, progress.md 2026-08-23), and the initial
  load conversion point has not been identified. Kept as a future
  alternative, not the plan of record.
- **Keying the hook by localisation key:** impossible at this hook;
  SetText never receives a key (item 6).
- **Dropping the env-var probe once files work:** rejected for now;
  it remains the smallest reproducible test input for the hook.

## Open decisions for the owner

1. English source side: read the game's yml at load (option a) or
   ship a derived source file (option b)?
2. Collision rule: skip-and-log (proposed) or a priority rule?
3. Env-var precedence: override-when-set (proposed) or reject the
   combination as a configuration error?
4. Submodule initialisation and `PARATRANZ_SECRET` provisioning
   (carried over from item 6).
5. Whether Stage D (decode enablement / Ghidra loop-2 exploration)
   is scheduled before or after Stages B-C, given it is the only
   stage that makes Japanese actually display.

## Summary

The migration is a join, not a rewrite: reuse `translationMap`,
add an English source map, invert through English values with a
skip-on-ambiguity rule, encode targets to the escape form with a
new pure encoder, and feed the existing `ProbeMapping` table behind
an opt-in switch with the env-var probe kept as an override. The
two hard limits are already proven, not speculative: escaped
Japanese costs 3 bytes per character against a measured SSO
capacity of 15, and the Linux decode hooks are still TODO, so the
loader can be completed and verified at the log/fixture level
before Japanese display is possible at all.
