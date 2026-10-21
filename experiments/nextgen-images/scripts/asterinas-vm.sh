#!/usr/bin/env bash
# Asterinas NixOS v0.19.0: VM lab ONLY. Never touches tablet or EFI.
set -euo pipefail
TAG=v0.19.0
REV=c4b7ed575b7b32773475b194d2ad41fb6d03765b
SRC="${ASTERINAS_SOURCE:-$HOME/src/asterinas-v0.19.0}"
case "${1:-help}" in
  fetch)
    if test ! -d "$SRC/.git"; then
      git clone --depth 1 --branch "$TAG" https://github.com/asterinas/asterinas.git "$SRC"
    fi
    test "$(git -C "$SRC" rev-parse HEAD)" = "$REV" || {
      echo "Unexpected Asterinas revision; refusing to build" >&2; exit 1;
    }
    echo "Asterinas $TAG pinned at $REV in $SRC"
    ;;
  kernel)
    test "$(git -C "$SRC" rev-parse HEAD)" = "$REV"
    ( cd "$SRC" && make kernel )
    ;;
  nixos)
    test "$(git -C "$SRC" rev-parse HEAD)" = "$REV"
    ( cd "$SRC" && make nixos )
    ;;
  run)
    test "$(git -C "$SRC" rev-parse HEAD)" = "$REV"
    ( cd "$SRC" && make run_nixos )
    ;;
  *)
    cat <<'HELP'
Asterinas 0.19.0 VM-only (Linux x86_64 builder with Docker/dev shell,
QEMU and sufficient disk). Mac Colima/Rosetta is not proven for nested QEMU.
  ./asterinas-vm.sh fetch   - clone and verify upstream tag
  ./asterinas-vm.sh kernel  - build kernel (inside upstream supported dev environment)
  ./asterinas-vm.sh nixos   - build Asterinas NixOS VM image
  ./asterinas-vm.sh run     - boot Asterinas NixOS in QEMU
No hardware image is promised. No script installs to the Lenovo tablet.
HELP
    ;;
esac
