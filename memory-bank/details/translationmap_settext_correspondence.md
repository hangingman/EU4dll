# translationMap keys vs SetText arguments: correspondence check

Recorded 2026-11-21 (item 6). Question: do the keys of `translationMap`
(the translation-data side) correspond to the strings actually passed
to `CTextSprite::SetText`? Checked against the DLL log of a real run.
No implementation was changed.

## Conclusion

There is **no direct correspondence** in either direction:

1. `translationMap` keys are localisation keys (for example
   `MENU_BAR_LOAD_GAME`). SetText never receives a key; it receives the
   already-resolved display text. In the `l_english` session used for
   verification, that text is the English value of the key in the
   game's own localisation files.
2. `translationMap` values are the target-language (Japanese)
   translations of the same keys. They are not what SetText receives
   in an English session either.
3. The only bridge is indirect: key -> English value in the game's
   `localisation/*_l_english.yml` -> SetText argument. Two of the three
   keys checked follow this bridge in the real log; the third was not
   observed passing through SetText at all in a main-menu run.
4. The SetText hook never consults `translationMap` (item 5), so this
   correspondence is informational only. Any future dictionary linkage
   (TODO.txt item 5) must join on the English value, not on the key,
   and must handle keys whose English text never reaches SetText.

## Correspondence table

Sources: game localisation
`~/.steam/debian-installation/steamapps/common/Europa Universalis IV/localisation/EU4_l_english.yml`;
DLL log of run `~/work/eu4-run/runs/20261121-124618` (eu4_smoke.sh,
Xvfb, `EU4DLL_SETTEXT_PROBE=1`,
`EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Connect to ID=Connect to JP;Load Game=Load Game'`,
`EU4DLL_TRANSLATION_OBSERVATION_KEYS='BACK,CONNECT_TO_IP,MENU_BAR_LOAD_GAME'`;
EU4 ended by the Exit button, `eu4_wait=0`).

| Localisation key (translationMap key) | English value (bridge) | Passed to SetText? (DLL log) | translationMap value in this run |
| --- | --- | --- | --- |
| `BACK` | `Back` (4 bytes) | Yes: `SetText capacity id=0 length=4 capacity=15`, `mapping id=0 result=applied` | `status=missing` (map empty, see below) |
| `CONNECT_TO_IP` | `Connect to ID` (13 bytes) | Yes: `SetText capacity id=1 length=13 capacity=15`, `mapping id=1 result=applied` | `status=missing` |
| `MENU_BAR_LOAD_GAME` | `Load Game` (9 bytes) | Not observed: mapping id=2 produced no `applied`, `capacity`, or `content-mismatch` line in the whole main-menu run | `status=missing` |

Notes on the table:

- `result=applied` proves the string passed through SetText and was
  replaced; it does not by itself prove the replacement was displayed
  (item 2 recorded the same caveat for `Connect to ID`).
- For `MENU_BAR_LOAD_GAME`, absence of any id=2 line means no 9-byte
  value equal or unequal to `Load Game` was logged as a candidate in
  this run. Why `Load Game` does not reach the observed `rdx` CString
  on the main menu (different text path, different overload, or not
  rendered through `CTextSprite::SetText` in this state) is unproven;
  it is recorded as not observed, not as a proven mismatch.
- Test fixtures are not real translation data: in
  `tests/resources/test_translation.yml` and the variant fixture in
  `tests/plugin/test_mod.d`, `MENU_BAR_LOAD_GAME` maps to the Japanese
  value `ロード`. Those values only prove the loader stores key ->
  Japanese value; they are not the shipped mod's values.

## Why the real translationMap was empty in this environment

The same run's `pattern_eu4jps.log` shows the mismatch is also
environmental:

- `loadTranslationMods`: `Mod directory not found: /home/agent/.local/share/Paradox Interactive/Europa Universalis IV/mod`
- `PluginVersion.init: Translation map contains 0 entries.`
- `Translation observation: key=BACK status=missing`,
  `key=CONNECT_TO_IP status=missing`,
  `key=MENU_BAR_LOAD_GAME status=missing`

`loadTranslationMods()` (source/plugin/mod.d) only reads `.yml` files
under that Paradox mod directory. No mod files are placed there in the
agent Xvfb environment, so no real key -> Japanese value pair could be
listed in this run.

## Blocker for real translation values: submodule not initialised

Filling in the real Japanese values requires the generated mod files.
Per `memory-bank/03_development_guide.md` and the `Makefile`, those
files are generated from the `submodules/EU4JPModAppendixI` submodule
(`source/localisation/`, produced by its `main.py`, which needs a
`PARATRANZ_SECRET`) and then placed where the game/DLL can read them.

State in this run: the submodule is **not initialised**
(`git submodule status` shows `-19be99ed9b53af21ca42c80be93beb24ea3b3759`,
the directory is empty). Per the task instruction, the submodule was
not fetched and no large download was started. Initialising it (and
providing the Paratranz secret for generation) is a decision for the
owner; until then the real-value column of the table stays empty and
the correspondence above rests on the game's English localisation as
the bridge, plus the loader's test fixtures for the value side.

## Implications for item 7

- A translation-file loader cannot key SetText replacements by
  localisation key directly; it must invert the map through the
  game's English values (key -> English source text -> Japanese
  target), and English values are not unique in general (different
  keys can share one English string), so collisions need a rule.
- Keys whose English text never reaches SetText (observed for
  `MENU_BAR_LOAD_GAME` in a main-menu run) cannot be replaced at this
  hook at all; the design must not promise full coverage.
- Even a correct source -> target pair still hits the item 5 result:
  the target must be supplied in the escaped form, and no
  UTF-8-to-escape converter exists yet.
