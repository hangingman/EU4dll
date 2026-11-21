# SetText dictionary from translation files (Stage B + C)

Recorded 2026-11-21. Implements Stage B and the Stage C storage change
of `translation_file_loading_design.md` together, on top of two
prerequisites that have landed since the design was written: the
UTF-8-to-escape encoder (item 10, wired into the hook in item 20) and
decode enabled by default. The owner's translation yml is also in
place (145 files in the mod folder).

## What changed

- `plugin/mod.d`
  - The per-file yml procedure of `loadTranslationMods` (BOM/header
    normalisation via `normalizeLocalizationYaml`, dyaml parse, every
    language section's scalar pairs, and all per-file log lines) is
    factored into a private `parseLocalisationFile`. `loadTranslationMods`
    behaviour and logs are unchanged; it now merges the helper's
    result into `translationMap`.
  - New public `loadLocalisationMap(dirPath)`: parses every `*.yml`
    under a directory (recursive) into one key -> value map with the
    same procedure. Later files overwrite earlier keys, matching the
    `translationMap` merge behaviour.
  - New public `gameLocalisationDir()`: the game's own localisation
    directory. Default is `<dir of /proc/self/exe>/localisation`
    (the EU4 install directory when the DLL is preloaded);
    `EU4DLL_GAME_LOCALISATION_DIR` overrides it.
  - New pure `joinTranslationDictionary(japaneseByKey, englishByKey)`
    with `TranslationJoinResult` / `TranslationJoinStats` (below).
- `plugin/localization/settext_hook.d`
  - Source selection in `loadSetTextMappings`: when
    `EU4DLL_SETTEXT_REPLACEMENTS` is set it wins, the file dictionary
    is not read, and a `source=env` line is logged. Otherwise
    `EU4DLL_SETTEXT_FROM_TRANSLATIONS=1` builds the dictionary from
    the files. With neither set, behaviour is the historical probe
    with no mappings. The `initSetTextHook` gate (v1.37.5 and
    `EU4DLL_SETTEXT_PROBE=1`) is unchanged.
  - Dictionary storage is Stage C shape: a dynamic `ProbeMapping[]`
    plus an associative array from the exact English source bytes to
    the mapping index. `tryReplaceDict` mirrors the probe path's
    CString reading, capacity check, write procedure and log formats
    (`formatSetTextReplacementLog`, `formatSetTextCapacityLog`, the
    plain `SetText replacement applied` marker); a lookup miss is not
    an outcome for any mapping and stays unlogged. The once-log flags
    are dynamic arrays parallel to the mappings.
  - Each joined entry is prepared with the existing
    `prepareSetTextReplacement` via the pure `buildDictMapping`,
    which reports the skip reason: `source-length` (source empty or
    over `MaxProbeBytes`), `empty-replacement` (target empty; the
    probe path rejects those too, and applying one would blank the
    text), `replacement-length` (prepared bytes over
    `MaxProbeBytes`), `unencodable` (target cannot be escape
    encoded). Entries are inserted in sorted source order so mapping
    ids are stable between runs.
  - One info line at load:
    `SetText mapping source=translations dir=... loaded=N joined=N deduplicated=N ambiguous=N skipped-source-length=N skipped-empty-replacement=N skipped-replacement-length=N skipped-unencodable=N english-keys=N japanese-keys=N`.

## Join semantics and the statistics

Only keys present in both maps take part (`commonKeys`). The output
is keyed by the English display text, because SetText receives the
resolved text, never the localisation key (item 6).

- Same English, same Japanese: collapsed into one entry
  (`deduplicated` counts the extra pairs folded away).
- Same English, different Japanese: the whole entry for that English
  string is dropped and counted once in `ambiguous` (per distinct
  English string, not per key). Later keys naming the same English
  string do not revive it and are not counted again. First-wins was
  rejected in the design because iteration order would silently
  choose user-visible text.
- `japaneseOnlyKeys` / `englishOnlyKeys`: keys present on one side
  only; they never enter the dictionary.
- `joined` in the load log is the size of the inverted dictionary
  before the byte-length limits; `loaded` is what survived
  `buildDictMapping`.

Empty English values are not special-cased by the join; the hook
loader drops them under `skipped-source-length` because a zero-length
source can never match a CString value.

## Expected dictionary size (measured 2026-11-21, rough line parse)

Counted with a simple line parser over the real files (not the dyaml
path, so treat as an estimate): the mod folder's 145 yml files hold
126,744 keys and the game's 143 `*_l_english.yml` files hold the
same 126,744 keys (the translation set mirrors the full game key
set; 122,881 of the mod values contain CJK). Joining gives 106,011
distinct English strings, with 14,754 deduplicated pairs and 1,530
ambiguous English strings dropped. After the 256-byte limits about
92,518 entries would load (10,107 sources too long - one of them an
empty English value - 3,378 prepared replacements too long, 8 empty
Japanese values skipped as empty-replacement, 0 unencodable). Note most of those entries
will still be skipped at runtime by the CString capacity check
(SSO capacity 15), as the design doc records; that is the expected
`exceeds-capacity` outcome, not a load failure.

## Tests

- `tests/plugin/test_mod.d`: new cases for `loadLocalisationMap`
  (recursive merge over a fixture tree, missing directory),
  `joinTranslationDictionary` (both-sides-only, dedup, ambiguous
  drop incl. a third key, one-sided key counts), and the
  `EU4DLL_GAME_LOCALISATION_DIR` override.
- `settext_hook.d` unittest: `buildDictMapping` reasons
  (none / source-length / replacement-length / unencodable,
  escaped vs verbatim preparation) and `findDictMapping` exact-match
  hits and misses.
- `make test`: 10 modules passed unittests (dub test exit 0; the
  fixture log shows the 4-entry map load). `make all` run last, so
  the normal build is in place.

## Not done here

No EU4 smoke run (per instruction). The first real-game run with
`EU4DLL_SETTEXT_PROBE=1 EU4DLL_SETTEXT_FROM_TRANSLATIONS=1` still
has to confirm the load log line against the real dictionary and
observe `result=applied` for a string whose capacity allows it.
