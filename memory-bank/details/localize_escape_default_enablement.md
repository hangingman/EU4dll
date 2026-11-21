# Localisation escape enablement: default on, EU4DLL_LOCALIZE_ESCAPE=0 opts out

Recorded 2026-11-21. The localisation-load escape hook
(memory-bank/details/localize_escape_hook.md) shipped as opt-in
(`EU4DLL_LOCALIZE_ESCAPE=1`) because it had never run on the real
machine. It has since been verified end to end: with the wide-path
fix in place, the throwaway translation mod renders Japanese across
the Game Browser and the country-select screen, and the owner
confirmed a successful launch with the mod, fonts, and hook on
2026-11-21. The owner then decided to flip the default, mirroring
the decode enablement (memory-bank/details/
decode_default_enablement.md), so a translation mod works without
setting an environment variable first.
`EU4DLL_LOCALIZE_ESCAPE=0` remains as the opt-out.

## Change (source/plugin/localization/localize_escape_hook.d only)

- New pure helper `localizeEscapeEnabled(value) == (value != "0")`,
  the same shape as `decodeEnabled` in dllmain.d. Unset, empty,
  "1", or any other value enables the hook; exactly "0" disables
  it.
- `initLocalizeEscapeHook` now returns early only when
  `localizeEscapeEnabled(environment.get("EU4DLL_LOCALIZE_ESCAPE"))`
  is false, and logs "[DIAGNOSTIC] EU4DLL_LOCALIZE_ESCAPE=0;
  localisation escape hook not installed" in that case. The
  v1.37.5 version gate ahead of it is unchanged, and dllmain.d
  wiring needed no change (the environment check lives inside the
  init function).
- The module header comment no longer describes the hook as
  opt-in.
- Unit tests added for the helper: null (unset) / "" / "1" /
  "true" enabled, "0" disabled.

## Verification

- `make test`: 11 modules passed unittests. `make all` run last
  (normal build in place).
- No EU4 run for this change (machine CPU is the owner's while he
  is playing). The default-on path is the identical code path the
  verified runs exercised with EU4DLL_LOCALIZE_ESCAPE=1; the only
  new behaviour is the decision function, covered by the unit
  tests above.
