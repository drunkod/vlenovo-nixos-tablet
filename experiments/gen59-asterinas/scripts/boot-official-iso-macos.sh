#!/usr/bin/env bash
# Safe Asterinas NixOS 0.19.0 VM boot on Apple Silicon via QEMU x86_64 TCG.
# Never accesses the Lenovo tablet; keeps the ISO read-only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GIT_COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
ARCHIVE="${ASTERINAS_ARCHIVE_DIR:-$(dirname "$GIT_COMMON")/.local/archives}"
ISO="${ASTERINAS_ISO:-$ARCHIVE/asterinas-nixos-0.19.0-x86_64.iso}"
SHA="7df9fafed4fe886e44bda501834937d893e12a05af911fabeb068c34379fb86e"
QEMU="${QEMU:-qemu-system-x86_64}"
SHARE="/opt/homebrew/share/qemu"
OVMF="${OVMF:-$SHARE/edk2-x86_64-code.fd}"
LOG="${ASTERINAS_VM_LOG:-$ARCHIVE/asterinas-gen59-vm-serial.log}"
MEM="${ASTERINAS_VM_RAM_MB:-3072}"
PORT="${ASTERINAS_VNC_DISPLAY:-27}"
case "${1:-help}" in
  check)
    test -f "$ISO" || { echo "Missing release ISO: $ISO" >&2; exit 1; }
    echo "$SHA  $ISO" | shasum -a 256 -c -
    command -v "$QEMU"
    test -f "$OVMF" || { echo "Missing UEFI firmware: $OVMF" >&2; exit 1; }
    echo "VM requirements verified; $MEM MiB RAM, VNC 127.0.0.1:$PORT"
    ;;
  boot)
    "$0" check
    echo "QEMU with x86 TCG (no KVM on Apple Silicon), serial log: $LOG"
    echo "VNC address: vnc://127.0.0.1:$((5900+PORT)) (localhost only)"
    exec "$QEMU" -machine q35,accel=tcg -cpu max -smp 2 -m "$MEM" \
      -drive "if=pflash,format=raw,readonly=on,file=$OVMF" \
      -drive "file=$ISO,media=cdrom,readonly=on,format=raw" -boot order=d \
      -device VGA -display "vnc=127.0.0.1:$PORT" \
      -serial "file:$LOG" -monitor none -nic user,model=virtio-net-pci -no-reboot
    ;;
  *)
    cat <<'HELP'
Usage: ./boot-official-iso-macos.sh check|boot
First download and verify the official ISO:
  gh release download v0.19.0 -R asterinas/asterinas --pattern 'asterinas-nixos-0.19.0-x86_64.iso' --dir .local/archives
  ./boot-official-iso-macos.sh check
  ./boot-official-iso-macos.sh boot

This is a QEMU x86_64 virtual machine, NOT a Lenovo physical NixOS
generation. Hardware virtualization is unavailable on Apple Silicon
for x86 guests; expect slow software emulation. ISO is read-only; no
virtual installation disk is attached and physical disks are untouched.
VNC listens on loopback only; serial output is saved to ARCHIVE.
HELP
    ;;
esac
