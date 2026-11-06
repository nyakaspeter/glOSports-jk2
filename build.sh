#!/bin/sh
# Cross-build Jedi Outcast SP (OpenJK at the commit below in upstream/, fetched
# and patched with patches/ on the first run) for
# goodluckOS in the jk2-builder Docker image (docker/Dockerfile.builder), into
# build/. package.sh then assembles out/ports/jk2/.
# Optimisation (defaults: LTO=1 PGO=use, the training profile committed in pgo/):
#   LTO=0           no link-time optimisation
#   PGO=generate    instrumented build: play it, quit from the menu, the profile
#                   lands in /dev/shm/jk2pgo on the console (tools/pgo.sh)
#   PGO=off         ignore the profile
set -eu
cd "$(dirname "$0")"
OPENJK=260c59c2907187af555a676fe0cc798893bf7757
if [ ! -d upstream ]; then
	git init -q upstream
	git -C upstream fetch -q --depth 1 https://github.com/JACoders/OpenJK "$OPENJK"
	git -C upstream checkout -q FETCH_HEAD
	git -C upstream apply "$PWD"/patches/*.patch
fi
LTO=${LTO:-1}
PGO=${PGO:-use}
[ "$PGO" = use ] && ! ls pgo/*.gcda >/dev/null 2>&1 && { echo "build.sh: no profile in pgo/, building without (PGO=off)"; PGO=off; }
docker image inspect jk2-builder:bookworm >/dev/null 2>&1 ||
	docker buildx build -q -f docker/Dockerfile.builder -t jk2-builder:bookworm --load docker
docker run --rm -v "$PWD":/w -w /w -e LTO="$LTO" -e PGO="$PGO" jk2-builder:bookworm sh -c '
set -e
flags=""
[ "$LTO" = 1 ] && flags="$flags -flto=auto -fuse-linker-plugin -ffat-lto-objects"
case "$PGO" in
generate) flags="$flags -fprofile-generate=/dev/shm/jk2pgo -fprofile-update=atomic"; link="-latomic" ;;
use) flags="$flags -fprofile-use=/w/pgo -fprofile-partial-training -Wno-missing-profile -Wno-coverage-mismatch"; link="" ;;
*) link="" ;;
esac
echo "optimisation flags:$flags"
cmake -S upstream -B build -DCMAKE_TOOLCHAIN_FILE=/w/toolchain-armhf.cmake -DCMAKE_BUILD_TYPE=Release \
	-DCMAKE_C_FLAGS="$flags" -DCMAKE_CXX_FLAGS="$flags" \
	-DCMAKE_EXE_LINKER_FLAGS="$flags $link -Wl,--export-dynamic-symbol=ioctl" -DCMAKE_SHARED_LINKER_FLAGS="$flags $link" \
	-DCMAKE_AR=/usr/bin/arm-linux-gnueabihf-gcc-ar -DCMAKE_RANLIB=/usr/bin/arm-linux-gnueabihf-gcc-ranlib \
	-DGlosGLES1=ON -DBuildPortableVersion=ON \
	-DBuildMPEngine=OFF -DBuildMPRdVanilla=OFF -DBuildMPDed=OFF -DBuildMPGame=OFF -DBuildMPCGame=OFF -DBuildMPUI=OFF -DBuildMPRend2=OFF \
	-DBuildSPEngine=OFF -DBuildSPGame=OFF -DBuildSPRdVanilla=OFF \
	-DBuildJK2SPEngine=ON -DBuildJK2SPGame=ON -DBuildJK2SPRdVanilla=ON >/dev/null
cmake --build build --clean-first -j$(nproc) 2>&1 | grep -E "error|Built target" | sort -u
'
