# Debian packaging

Recorded 2026-11-22. Branch `work/debian-package`.

## Goal

Bundle everything a working setup needs into one .deb, so a fresh
machine does not need the manual steps (build the .so, copy it into
the game directory, assemble the mod from the localisation files and
the generated fonts): the preload library, the eu4dll_translations
mod data (localisation yml and generated fonts) and small helper
scripts.

## Layout

- `usr/lib/eu4dll/libeu4dll.so`: the preload library, built by
  `dub build --compiler=ldc2` during the package build.
- `usr/share/eu4dll/mod/eu4dll_translations/`: mod data
  (`localisation/*.yml`, `gfx/fonts/*.fnt` and `*.tga`), plus the
  `eu4dll_translations.mod` descriptor next to it.
- `usr/bin/eu4dll-install-mod`: per-user setup. Copies the mod data
  into `~/.local/share/Paradox Interactive/Europa Universalis IV/mod/`
  and adds `mod/eu4dll_translations.mod` to `enabled_mods` in
  `dlc_load.json` (the previous file is kept as `dlc_load.json.bak`).
  Safe to re-run: the entry is added once and the mod files are
  refreshed.
- `usr/bin/eu4dll-launch`: starts the game from its install directory
  with `LD_PRELOAD=/usr/lib/eu4dll/libeu4dll.so`. `EU4_DIR` overrides
  the game directory.

## Build

```sh
EU4DLL_MOD_SRC=/path/to/mod/eu4dll_translations dpkg-buildpackage -us -uc -b
```

- The mod data is not stored in this repository (the yml files come
  from the EU4JPModAppendixI project and the fonts are generated
  locally, 154 MB uncompressed). `debian/rules` copies it from
  `EU4DLL_MOD_SRC`, defaulting to the building user's Paradox mod
  directory, and fails with a clear message when it is missing.
- `debian/rules` clears `DFLAGS` for the dub build: dpkg-buildflags
  exports a DFLAGS value containing `-frelease`, which ldc2 rejects.
- Build-Depends use the Debian package name `ldc` (it provides the
  `ldc2` binary), not `ldc2`.
- Source format is `3.0 (native)`, version `0.1`.

## Verification (2026-11-22, on the build machine)

- `dpkg-buildpackage -us -uc -b` succeeds. The package is
  12.7 MB (the font .tga files compress well), Installed-Size
  175829 KB. Computed Depends: `libc6 (>= 2.34)`,
  `libgcc-s1 (>= 3.0)`, `libphobos2-ldc-shared110 (>= 1:1.40.0)`.
- Contents checked with `dpkg-deb -c`: 145 localisation yml files,
  32 font files, the library, both helper scripts (executable) and
  the .mod descriptor.
- The packaged library passes the preload-guard check:
  `LD_PRELOAD=<packaged .so> /bin/true` exits 0 silently.
- `eu4dll-install-mod` was run against a scratch `XDG_DATA_HOME`:
  all 145 yml and 32 font files copied, `dlc_load.json` created with
  the mod enabled, a second run did not duplicate the entry and left
  a `dlc_load.json.bak`.
- Not verified: installing the .deb on a second machine and an
  in-game run using only the packaged files. The game itself was not
  started for this change.
