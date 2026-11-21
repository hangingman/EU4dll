# EU4DLL

This dll makes it possible to display double-byte characters on Europa Universalis IV.

## Getting Started

### Prerequisites

- A D language compiler. LDC 1.43.0 or later is required (older LDC cannot build the naked inline assembly in source/plugin/main_text.d and source/plugin/font.d). We recommend LDC. You can install it via the official installer:
  ```sh
  curl -fsSL https://dlang.org/install.sh | bash -s ldc
  ```
- Git

### Installation

1. Clone the repository and its submodules:
   ```sh
   git clone --recursive https://github.com/hangingman/EU4dll.git
   cd EU4dll
   ```

2. Build the project:
   The project is configured to be built with LDC.
   ```sh
   make all
   ```
   Alternatively, you can run the dub command directly:
   ```sh
   dub build --compiler=ldc2
   ```

## Licence

MIT Licence

## Thanks

This dll was forked by the following project. Thank you so much.

[EU4DLL](https://github.com/matanki-saito/EU4dll)

## Debian package

The library, the eu4dll_translations mod data (localisation files and
generated fonts) and two helper scripts can be bundled into a .deb:

```sh
EU4DLL_MOD_SRC=/path/to/mod/eu4dll_translations dpkg-buildpackage -us -uc -b
```

The mod data is not stored in this repository. `EU4DLL_MOD_SRC` must
point at a eu4dll_translations mod directory; without it, the current
user's Paradox mod directory is used.

Install the package and set up the mod for your user:

```sh
sudo apt install ../eu4dll_0.1_amd64.deb
eu4dll-install-mod
eu4dll-launch
```
