# Third-party components

The port is OpenJK ([JACoders/OpenJK](https://github.com/JACoders/OpenJK), GPL-2.0) with the patches in
`patches/`, which are under the same licence (`LICENSE`, the GPL-2.0 text from OpenJK: in the repo's root, and beside this file in the game folder). It ships with:

| Component | Licence | Text |
|---|---|---|
| libjpeg-turbo (`lib/libjpeg.so.62`, Debian bookworm `libjpeg62-turbo`) | IJG, BSD-3-Clause, zlib | `libjpeg-turbo.copyright.txt` |
| ARM's Mali user-space driver (`glos/lib/libMali.so`) | ARM proprietary | `libMali.txt` |
| ARM's Mali kernel driver (`glos/mali.ko`) | GPL-2.0 | goodluckOS-mali-driver |

The game itself is not included: its `.pk3` files come from your own copy.
