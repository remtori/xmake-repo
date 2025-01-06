# Local xrepo package

Most of the package's xmake.lua is copied from the official [xmake-repo](https://github.com/xmake-io/xmake-repo), and modified to never look for system installed packages.

## Packages

- `harfbuzz` - modified to prevent from using system lib
- `libheif` -modified to prevent from using system lib
- `libpng` - modified to use CMake directly to ensure it supports all platforms
- `libwebp` - modified to prevent from using system lib
- `zlib` - modified to prevent from using system lib
