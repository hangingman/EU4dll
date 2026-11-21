# SetText file dictionary: removal

Recorded 2026-11-21. Implements the recommendation of
`settext_dict_position_review.md` ("fold the dictionary") on branch
`work/remove-settext-dict`. The review holds the full analysis; this
record is the removal summary.

## Why

- The localisation-load hook (on by default since 5b8acc7) covers
  the dictionary's original target, yml localisation, completely
  and per key, without the dictionary's structural limits
  (256-byte ceiling, CString capacity check, ambiguous drops).
- Measured effect was negligible: exactly one replacement applied
  in the dictionary's own verification run
  (runs/20261121-212246-multiplayer).
- Its one unique configuration (translation with the mod disabled)
  is blocked in practice because the generated fonts ship inside
  the same mod.
- It is not a fallback for the load hook: both are locked to
  v1.37.5 patterns and break together on a game update.

## What was removed

- `source/plugin/localization/settext_hook.d`: the dict storage
  (`dictMode`, `dictMappings`, `dictIndexBySource`, the three
  `dict*Logged` arrays), `loadTranslationDictMappings`,
  `buildDictMapping`, `findDictMapping`, `tryReplaceDict`, the
  `EU4DLL_SETTEXT_FROM_TRANSLATIONS` branch of
  `loadSetTextMappings` (probe-only afterwards), the dictionary
  branch of `setTextProbe`, the `plugin.mod` import of the three
  helpers, and the dictionary unittest blocks.
- `source/plugin/mod.d`: `loadLocalisationMap`,
  `gameLocalisationDir`, `joinTranslationDictionary`,
  `TranslationJoinResult`, `TranslationJoinStats`.
- Environment variables retired: `EU4DLL_SETTEXT_FROM_TRANSLATIONS`,
  `EU4DLL_GAME_LOCALISATION_DIR`.
- Tests: cases 8, 9, 10, 11, 11b and 12 of
  `tests/plugin/test_mod.d` (loadLocalisationMap /
  joinTranslationDictionary / EU4DLL_GAME_LOCALISATION_DIR).

## What stays

- The SetText hook itself and the env-var probe
  (`EU4DLL_SETTEXT_PROBE`, `EU4DLL_SETTEXT_REPLACEMENTS`): the
  diagnostic instrument the earlier items were verified with;
  `eu4_smoke.sh` still greps for its replacement marker.
- `parseLocalisationFile`, `loadTranslationMods` and
  `translationMap` in `mod.d` (they predate the dictionary and feed
  `plugin_version.d` and the translation observations).

## Verification

- Grep over `source/` and `tests/` after the edit: no remaining
  reference to any removed symbol or environment variable.
- `make test`: 11 modules passed unittests. `make all` run last to
  restore the normal build. No EU4 run (cleanup-only change; the
  hook path that remains is the probe, unchanged in behaviour when
  `EU4DLL_SETTEXT_FROM_TRANSLATIONS` was unset, which was always
  the default).
