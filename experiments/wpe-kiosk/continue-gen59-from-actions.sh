#!/usr/bin/env bash
# MacBook helper for finishing the Gen59 WPE build after native GitHub Actions.
# Source-only and Nix-store operations: NEVER activates or reboots the Lenovo.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/../.." && pwd)"
GIT_COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
RUN="${GEN59_WPE_CI_RUN:-39644717396}"
ARCHIVE="$(dirname "$GIT_COMMON")/.local/archives/gen59-wpe-ci-${RUN}"
REPO=drunkod/vlenovo-nixos-tablet
EXPECTED_PATCHED_SHA=d7dc855e938b8299b3f825ce56b959fd800b4209
DOCKER_CONTEXT=colima-vlenovo-flick-build
BUILDER=vlenovo-flick-nixbuild
FLAKE=path:/nextgen59-wpe
EXPECTED_GEN58=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
EXPECTED_KERNEL=/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36
EXPECTED_INITRD=/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36
NIX=(nix --extra-experimental-features "nix-command flakes" --option sandbox false
 --option filter-syscalls false --option max-jobs 2 --option cores 2)
dc() { docker --context "$DOCKER_CONTEXT" "$@"; }
builder() { dc exec "$BUILDER" "$@"; }
check_gen58() {
  local current
  current="$(ssh -F "$HOME/.ssh/vlenovo_config" -o BatchMode=yes vlenovo 'readlink -f /run/current-system')"
  [ "$current" = "$EXPECTED_GEN58" ] || {
    echo "SAFETY STOP: Gen58 is no longer current ($current)" >&2; exit 1;
  }
}
fetch() {
  mkdir -p "$ARCHIVE"
  gh run view "$RUN" -R "$REPO" --json conclusion --jq '.conclusion' | grep -Fx success
  test "$(gh run view "$RUN" -R "$REPO" --json headSha --jq '.headSha')" = "$EXPECTED_PATCHED_SHA" || {
    echo "SAFETY STOP: CI build is not the reviewed sandbox-patched commit" >&2; exit 1;
  }
  gh run download "$RUN" -R "$REPO" --name gen59-wpe2541-nix-outputs --dir "$ARCHIVE"
  (cd "$ARCHIVE" && shasum -a 256 -c wpe-outputs.sha256)
  zstd -t "$ARCHIVE/wpe-outputs.nar.zst"
  echo "IMPORTING_WPE_OUTPUTS_FROM_VERIFIED_NATIVE_CI"
  zstd -dc "$ARCHIVE/wpe-outputs.nar.zst" | dc exec -i "$BUILDER" nix-store --import
  while IFS= read -r path; do
    builder nix-store --verify-path "$path"
  done < "$ARCHIVE/wpe-store-paths.txt"
}
build_image() {
  dc cp "$DIR/." "$BUILDER:/nextgen59-wpe"
  echo BUILD_KIOSK
  builder "${NIX[@]}" build "$FLAKE#packages.x86_64-linux.kiosk" --no-link --print-out-paths -L
  echo BUILD_GEN59_SYSTEM
  builder "${NIX[@]}" build "$FLAKE#nixosConfigurations.gen59-wpe.config.system.build.toplevel" --no-link --print-out-paths -L | tee "$ARCHIVE/gen59-system-path.txt"
  local kernel initrd
  kernel="$(builder "${NIX[@]}" eval --raw "$FLAKE#nixosConfigurations.gen59-wpe.config.system.build.kernel.outPath")"
  initrd="$(builder "${NIX[@]}" eval --raw "$FLAKE#nixosConfigurations.gen59-wpe.config.system.build.initialRamdisk.outPath")"
  [ "$kernel" = "$EXPECTED_KERNEL" ] && [ "$initrd" = "$EXPECTED_INITRD" ] || {
    echo "SAFETY STOP: kernel/initrd differ from gen58" >&2; exit 1;
  }
  local system
  system="$(tail -1 "$ARCHIVE/gen59-system-path.txt")"
  builder nix-store --verify-path "$system"
  echo "READY_FOR_STAGING=$system"
}
stage() {
  check_gen58
  local system
  system="$(tail -1 "$ARCHIVE/gen59-system-path.txt")"
  case "$system" in /nix/store/*-nixos-system-vlenovo-*) ;; *) echo "Bad image path" >&2; exit 1;; esac
  builder nix-store --verify-path "$system"
  builder nix-store -qR "$system" | LC_ALL=C sort -u > "$ARCHIVE/gen59-closure.txt"
  ssh -F "$HOME/.ssh/vlenovo_config" -o BatchMode=yes vlenovo 'nix-store -qR /run/current-system' |
    LC_ALL=C sort -u > "$ARCHIVE/gen58-closure.txt"
  comm -13 "$ARCHIVE/gen58-closure.txt" "$ARCHIVE/gen59-closure.txt" > "$ARCHIVE/needed-paths.txt"
  echo "NEW_STORE_PATHS=$(wc -l < "$ARCHIVE/needed-paths.txt")"
  if [ -s "$ARCHIVE/needed-paths.txt" ]; then
    dc cp "$ARCHIVE/needed-paths.txt" "$BUILDER:/tmp/gen59-wpe-needed-paths.txt"
    builder sh -c 'nix-store --export $(cat /tmp/gen59-wpe-needed-paths.txt)' |
      ssh -T -F "$HOME/.ssh/vlenovo_config" -o BatchMode=yes vlenovo 'sudo -n nix-store --import'
  fi
  ssh -F "$HOME/.ssh/vlenovo_config" -o BatchMode=yes vlenovo "sudo -n nix-store --verify-path '$system'"
  check_gen58
  echo "STAGED_BUT_NOT_ACTIVATED=$system"
}
case "${1:-help}" in
  fetch) fetch ;;
  build) build_image ;;
  stage) stage ;;
  all) fetch; build_image; stage ;;
  *)
    echo "Usage: $0 fetch|build|stage|all"
    echo "Never switches system profile, display service, GRUB or physical kernel."
    exit 0 ;;
esac
