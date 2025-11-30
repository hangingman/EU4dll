# EU4DLL

This dll makes it possible to display double-byte characters on Europa Universalis IV.

## Getting Started

### Prerequisites

- A D language compiler. We recommend LDC. You can install it via the official installer:
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
