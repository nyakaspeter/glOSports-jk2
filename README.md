# glOSports-jk2 — Star Wars Jedi Knight II: Jedi Outcast, native, on the GA36-MB

Jedi Outcast's single player through [OpenJK](https://github.com/JACoders/OpenJK)
(GPL-2.0, the game's released source), cross-built for goodluckOS on the
GA36-MB (Allwinner A33, Mali-400 MP2, 640×480). The vanilla renderer's desktop
OpenGL 1.x runs on **GLES 1.1 on ARM's closed Mali driver** through a small
translation layer of our own (no gl4es), drawing to `/dev/fb0` through EGL.
The game folder carries its own `glos/` (see `goodluckOS-mali-driver`); the console
stays stock goodluckOS.

## Game files

From the PC game (retail CD 1.02, or a Steam/GOG install), into
`/home/player/ports/jk2/base/`:

| File | Where it comes from | Needed |
|---|---|---|
| `assets0.pk3` | the game's `GameData/base/` (on the CD: `GAMEDATA/GameData/base/`) | yes |
| `assets1.pk3` | the same folder | yes |
| `assets2.pk3` | patch 1.03 or 1.04 (identical in both; Steam/GOG installs already have it) | recommended: key names in the Controls menu, updated texts; the game runs without it |

Nothing else: no `.exe`/`.dll` (OpenJK replaces them), no `assets5.pk3`
(multiplayer scripts only). The patches are Windows installers;
`tools/jkiiup-extract.py JKIIUp104.exe outdir` takes `assets2.pk3` out of one
without running it (`outdir/Common/GameData/base/assets2.pk3`).

## The game folder on the console (`/home/player/ports/jk2/`)

| Path | What |
|---|---|
| `start.sh` | sets the pad layout and stick shaping, starts the game through `glos/glos-gpu run mali`; log in `/dev/shm/jk2.log` |
| `openjo_sp.arm`, `rdjosp-vanilla_arm.so`, `OpenJK/jospgamearm.so` | engine, renderer, game code |
| `lib/libjpeg.so.62` | the one library goodluckOS lacks (the renderer finds it through an `$ORIGIN/lib` rpath) |
| `glos/` | ARM's driver set from `goodluckOS-mali-driver` |
| `icon.png` | launcher image (192×128) |
| `base/*.pk3` | game files (above) |
| `base/glos-pad.cfg` | pad bindings, run right after the game's `default.cfg` (at every start and on a settings reset) |
| `base/openjo_sp.cfg`, `base/saves/` | the player's settings and saves (portable build: nothing outside the folder) |

Launcher entry: `/home/player/.local/share/applications/jk2.puppy`.

## Controls

Positions as on an Xbox pad (A = bottom), like the GTA ports:

| Pad | In game | In menus |
|---|---|---|
| left stick | move (analog) | cursor |
| right stick | aim | cursor |
| R2 / L2 | fire, swing / alternate fire, saber throw | click / back |
| R1 / L1 | use force power / next force power | |
| A (bottom) / B (right) | jump / crouch | click / back |
| X (left) / Y (top) | use / next weapon | |
| d-pad ↑ ↓ ← → | saber style / use item / previous weapon / next item | cursor keys |
| L3 / R3 | walk / first-third person | |
| Select / Start | datapad / menu | — / back |

Rebinding in the Controls menu sticks (saved in `openjo_sp.cfg`); a settings
reset brings the pad layout back. Stick shaping in `start.sh`:
`JK2_STICK_SCALE=1.5` (the sticks reach ~2/3 of their range),
`JK2_STICK_DEADZONE=0.12` (radial; they rest up to 9% off centre after scaling),
`JK2_LOOK_SPEED=200` (degrees/second at full right stick), `JK2_LOOK_CURVE=2`.
`start.sh` also sets `cg_drawFPS 1` (FPS in the top right).

## Repo layout

| Path | What |
|---|---|
| `build.sh` | fetches OpenJK (pinned commit) into `upstream/` and applies `patches/` on the first run, cross-builds in Docker into `build/` (LTO + PGO by default) |
| `package.sh` | assembles `out/ports/jk2/` and `out/.local/share/applications/jk2.puppy` with `glos/` from `../goodluckOS-mali-driver/glos` |
| `patches/0001-glos-gles1-fbdev-gamepad.patch` | every change to OpenJK |
| `docker/Dockerfile.builder` | the build image (Debian bookworm, armhf cross compiler, SDL2/OpenAL/libjpeg/libpng armhf) |
| `pgo/` | the training profile (gcda files) |
| `tools/pgo.sh` | install the instrumented build, collect its profile |
| `tools/jkiiup-extract.py` | extract the patch installers' files |
| `start.sh`, `glos-pad.cfg`, `jk2.puppy`, `icon.png` | the folder's own files |

## Build, package, deploy

```
./build.sh && ./package.sh
```

Then copy `out/ports/jk2/` over `/home/player/ports/jk2/` (the game files and
saves in `base/` stay) and `out/.local/share/applications/jk2.puppy` next to
the other launcher entries. `package.sh` refuses a renderer with unresolved
`glos_` symbols (a GL call the layer doesn't implement: the renderer would fail
to load).

PGO: `PGO=generate ./build.sh && ./package.sh && tools/pgo.sh install`, play a
few minutes with fights, quit from the menu (or stop from the launcher; a kill
writes nothing; runs add up), `tools/pgo.sh collect`, then `./build.sh`.

## What the patch does

- **GLES 1.1 layer** (`code/rd-vanilla/tr_glos.cpp`, `tr_glos.h`; `GlosGLES1`
  CMake option): `qgl.h` routes every `qglX` to `glos_X`, which calls GLES 1.1 in
  `libMali.so` (loaded at runtime) or emulates the call: `glBegin`/`glEnd`
  through client arrays (quads and polygons as triangles; the game's arrays are
  put back after), `GL_QUADS` in `glDrawArrays` through a quad index list,
  double-precision calls to their float versions, texture uploads with
  internal format = format (RGBA, or RGB565/RGBA4444 for `r_texturebits 16`, half
  the texture memory), `GL_CLAMP` → `GL_CLAMP_TO_EDGE`, depth readback answered
  with "nothing in front". Extensions advertised: multitexture and
  `texture_env_add` only (GLES 1.1 core), so the NV/ARB program paths (dynamic
  glow) stay off. Indices are 16-bit (`glIndex_t`), and every draw is one
  `glDrawElements` (the strip path would go through emulated immediate mode).
- **Window** (`shared/sdl/sdl_glos.cpp`): EGL on `/dev/fb0` with a GLES 1.1
  context; no SDL video at all (goodluckOS's SDL has no dummy driver and lima is
  unbound while ARM's driver runs). The window, context and input live for the
  whole run, so changing a video setting (`vid_restart`) keeps them.
- **Pad** (`shared/sdl/sdl_glospad.cpp`): SDL game controller, radial dead zone,
  analog move and aim into `CL_JoystickMove`, buttons as JOY keys, menu mode with
  a stick cursor. It also reads SDL's event queue for `SDL_QUIT`: SDL turns
  SIGTERM (`appctl stop-application`, the launcher's stop) into that event, and
  without SDL video nothing else reads it.
- **Defaults**: `exec default.cfg` is followed by `exec glos-pad.cfg`.
- **NEON skinning** (`tr_ghoul2.cpp`): a vertex's bone matrices are blended by
  weight and the position transformed once (same result as the C path's sum of
  per-bone positions, the weights sum to 1).
- **Retail 1.02 data**: `strip/keynames.sp` is optional (only patch 1.03+ has
  it; key names then show raw).

### Tear-free flips

ARM's fbdev EGL returns from `eglSwapBuffers` at once and flips
(`FBIOPAN_DISPLAY`, which returns at the vblank) on a thread of its own, so
with two buffers the GPU could draw the next frame into the one still on
screen: tearing, and a flicker between two frames. `GLOS_Swap` now waits
before each flush until the previous frame's flip has landed; the binary
exports `ioctl` (`-Wl,--export-dynamic-symbol=ioctl`, default visibility) so
libMali's flips are counted there. `JK2_FLIP_WAIT=0` turns it off,
`JK2_LOG_FPS=1` logs fps and the wait. Jedi Outcast, `kejim_post`, standing
still: 47.1 fps (min 41.1) with the wait, 49.7 (min 33.6) without, which
tears. Carried over from glOSports-maxpayne.

## Measurements

Not benched (no repeatable fight scene was built). Played with
the FPS counter: ~50 fps in light scenes, ~30 in fights, before LTO + PGO and
NEON skinning; with them "fine" by eye, not measured. The main thread keeps one
core busy; the process used ~126 MB (RSS) in the first level, ~118 MB stayed free.

## Traps

- A kill (Fn+Start+Select) right after the game's last GPU job unloaded
  `mali.ko` while its delayed runtime-PM suspend was pending: kernel BUG,
  wedged console. Fixed in `goodluckOS-mali-driver` (`mali_remove` disables runtime PM
  first); every port's `glos/` carries the fixed module.
- Without the `SDL_QUIT` read, `appctl stop-application` did nothing.
- A settings reset ran `default.cfg`'s `unbindall` and dropped the pad bindings
  (now re-applied after `default.cfg`).

## Licence

OpenJK is GPL-2.0, and so are this port's patches to it and the rest of the
repo (`LICENSE`, the GPL-2.0 text from OpenJK). The bundled libjpeg-turbo and
ARM's Mali driver are listed with their licences in `licenses/`, which
`package.sh` copies into the game folder. The game itself is not included.
