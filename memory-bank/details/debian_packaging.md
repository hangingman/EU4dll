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

## Follow-up: LDC 1.43 (2026-11-22, package 0.2)

PR #9 changed the naked asm to the form LDC 1.43 requires. Two
consequences for the package:

- Debian's ldc (1.40) can no longer build the source: the references
  come out absolute and the link fails with
  `relocation R_X86_64_32S against hidden symbol ... can not be used
  when making a shared object`. This was reproduced in the owner's
  own build. debian/rules now checks the ldc2 version first and
  stops with a readable message. Build-Depends states
  `ldc (>= 1.43)`; building with the official release tarball needs
  `dpkg-buildpackage -d` because the tarball is invisible to dpkg.
- A library built with LDC 1.43 needs
  `libphobos2-ldc-shared.so.113` / `libdruntime-ldc-shared.so.113`,
  which Debian does not package. The package therefore bundles the
  compiler's shared runtime into `/usr/lib/eu4dll/` and sets the
  library rpath to `$ORIGIN` with patchelf. dh_shlibdeps runs with
  `--ignore-missing-info` so the bundled runtime does not turn into
  an unsatisfiable Depends. The D language is only used for this
  project on the target machines, so a self-contained package is
  the right shape.

Verification (2026-11-22, on the build machine):

- Built with the LDC 1.43 release on PATH: package builds,
  14.0 MB, and the generated Depends is only
  `libc6 (>= 2.34), libgcc-s1 (>= 4.2)` - no D runtime.
- The packaged library has RUNPATH `$ORIGIN`, and under `env -i`
  its libphobos/libdruntime resolve to the bundled copies in
  /usr/lib/eu4dll. `env -i LD_PRELOAD=<packaged .so> /bin/true`
  exits 0 silently (preload guard).
- Building with Debian's ldc 1.40 stops at the version check with
  the readable message quoted in debian/rules.
- eu4dll-install-mod from the 0.2 package passed the same scratch
  data-home check as 0.1.
- Not verified: installing the 0.2 .deb with apt on the target
  machine and an in-game run using only the packaged files.

## Follow-up: delta3 fonts adopted (2026-11-22, package 0.3)

- The owner compared the original, delta2 (2 px smaller) and
  delta3 (3 px smaller) generated font sets in game and adopted
  delta3 as the official set. Details and the size table:
  details/font_size_survey.md sections 6 and 7.
- debian/rules now checks, before copying the mod data, that the
  info size of every .fnt in EU4DLL_MOD_SRC matches the delta3
  table (16 fonts; for example vic_18 is 15, garamond_12 is 9,
  vic_36 is 33) and stops the build with a readable message
  otherwise. This keeps a non-delta3 set from being packaged by
  accident.
- The generator and its charset are bundled in the repository as
  tools/generate_fonts.py (DELTA defaults to 3) and
  tools/font_charset.tsv, so the official fonts can be regenerated
  from the repository alone.
- Package version is 0.3.
