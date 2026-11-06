#!/bin/sh
# Profile-guided optimisation for Jedi Outcast.
#   1. PGO=generate ./build.sh && ./package.sh
#   2. tools/pgo.sh install     put the instrumented build on the console
#   3. Play for a few minutes (fights included), then quit from the game's menu
#      (the profile is written on a clean exit, also on appctl stop-application).
#   4. tools/pgo.sh collect     fetch the profile into pgo/
#   5. ./build.sh && ./package.sh   (PGO=use LTO=1 are the defaults), install
# Re-train after large code changes; a stale profile still builds, just helps less.
set -eu
HERE=$(cd "$(dirname "$0")/.." && pwd)
ROOT=$(cd "$HERE/../goodluckOS-tools" && pwd)
pkg=$HERE/out/ports/jk2
console() { (cd "$ROOT" && GLOS_TIMEOUT=${T:-60} python3 -I console.py "$1"); }
send() { pkill -9 -x ptpcamerad 2>/dev/null || true; (cd "$ROOT" && python3 -I mtp_send.py / "$@" | grep -v '%' | tail -1); }

case "${1:-}" in
install)
    send "$pkg/openjo_sp.arm" "$pkg/rdjosp-vanilla_arm.so" "$pkg/OpenJK/jospgamearm.so"
    console "/usr/local/bin/appctl stop-application; sleep 3; rm -rf /dev/shm/jk2pgo; cd /home/player && mv -f openjo_sp.arm rdjosp-vanilla_arm.so ports/jk2/ && mv -f jospgamearm.so ports/jk2/OpenJK/ && chown player:player ports/jk2/openjo_sp.arm ports/jk2/rdjosp-vanilla_arm.so ports/jk2/OpenJK/jospgamearm.so && chmod +x ports/jk2/openjo_sp.arm && md5sum ports/jk2/openjo_sp.arm ports/jk2/rdjosp-vanilla_arm.so ports/jk2/OpenJK/jospgamearm.so"
    md5 -q "$pkg/openjo_sp.arm" "$pkg/rdjosp-vanilla_arm.so" "$pkg/OpenJK/jospgamearm.so"
    ;;
collect)
    console "pidof openjo_sp.arm && echo 'still running - quit it from the game menu first' && exit 1; ls /dev/shm/jk2pgo | wc -l; du -sh /dev/shm/jk2pgo"
    tmp=$(mktemp -d)
    T=300 console 'cd /dev/shm/jk2pgo && tar czf - . | base64 -w0; echo' | tr -d '\r\n' | base64 -d | tar xzf - -C "$tmp"
    n=$(ls "$tmp" | grep -c gcda || true)
    [ "$n" -gt 0 ] || { echo "no profile arrived; pgo/ left as it was"; rm -rf "$tmp"; exit 1; }
    rm -rf "${HERE:?}/pgo" && mv "$tmp" "$HERE/pgo"
    echo "$n profile files in pgo/"
    ;;
*)
    sed -n 2,9p "$0"
    exit 2
    ;;
esac
