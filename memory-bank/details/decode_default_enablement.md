# Decode enablement: default on, EU4DLL_ENABLE_DECODE=0 opts out

Recorded 2026-11-21. Owner decision (2026-11-21, after items 1-32
completed and the cleaned history landed on remote master): the
decode initialisers run by default so a translation mod works
without the operator setting an environment variable first.
`EU4DLL_ENABLE_DECODE=0` remains as the opt-out.

## Change (source/plugin/dllmain.d only)

- `decodeOptInEnabled(value) == (value == "1")` is replaced by
  `decodeEnabled(value) == (value != "0")`. Unset, empty, "1", or any
  other value enables decode; exactly "0" disables it.
- The pure helper keeps its unit tests, updated to the new semantics
  (null/""/"1"/"true" enabled, "0" disabled).
- Log lines updated: enabled path logs "Decode enabled (default;
  EU4DLL_ENABLE_DECODE=0 opts out); calling Font.init and
  TextView.init"; disabled path logs "EU4DLL_ENABLE_DECODE=0;
  skipping Font.init / TextView.init".
- Failure handling is unchanged: decode init errors are aggregated,
  logged, and never fatal (the PluginVersion gate remains the fatal
  one). The aggregate error line still appears on v1.37.5 because
  some injectors have no Linux counterpart by design; the identical
  line is present in the verified item 32 runs (e.g.
  runs/20261121-192004-multiplayer), so it is the known-good state,
  not a regression of this change.

## Verification

- `make test`: 10 modules passed unittests. `make all` run last
  (normal build in place).
- Smoke runs/20261121-210753 (no EU4DLL_ENABLE_DECODE in the
  environment): log shows the "Decode enabled (default; ...)" line,
  menu reached, ended by Exit button, eu4_wait=0, DLL [OK] once.
- Smoke runs/20261121-211038 (EU4DLL_ENABLE_DECODE=0): log shows the
  "skipping Font.init / TextView.init" line, menu reached, ended by
  Exit button, eu4_wait=0, DLL [OK] once.
- Both smokes used the fresh clone taken from remote master the same
  evening (14bbd76) plus this change.
