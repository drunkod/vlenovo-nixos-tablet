#!/usr/bin/env bash
# macOS Apple Silicon QEMU TCG lab for Asterinas NixOS v0.19.0.
# The ONLY writable virtual disk is a local qcow2 file on the Mac.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
GIT_COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
ARCHIVE="${ASTERINAS_ARCHIVE_DIR:-$(dirname "$GIT_COMMON")/.local/archives}"
ISO="${ASTERINAS_ISO:-$ARCHIVE/asterinas-nixos-0.19.0-x86_64.iso}"
SHA="7df9fafed4fe886e44bda501834937d893e12a05af911fabeb068c34379fb86e"
DISK="${ASTERINAS_VM_DISK:-$ARCHIVE/asterinas-gen59-test-disk.qcow2}"
QEMU="${QEMU:-qemu-system-x86_64}"
SHARE="/opt/homebrew/share/qemu"
OVMF="${OVMF:-$SHARE/edk2-x86_64-code.fd}"
VARS_TEMPLATE="${VARS_TEMPLATE:-$SHARE/edk2-i386-vars.fd}"
VARS="${ASTERINAS_OVMF_VARS:-$ARCHIVE/asterinas-gen59-ovmf-vars.fd}"
MEM="${ASTERINAS_VM_RAM_MB:-4096}"
PORT="${ASTERINAS_VNC_DISPLAY:-27}"
GUEST_NET="${ASTERINAS_VM_NET:-none}" # none (known-good) or virtio-modern (experimental)
MODE="${1:-help}"
LOG="${ASTERINAS_VM_LOG:-$ARCHIVE/asterinas-gen59-${MODE}-serial.log}"

check_iso() {
  test -f "$ISO" || { echo "Missing ISO: $ISO" >&2; exit 1; }
  echo "$SHA  $ISO" | shasum -a 256 -c -
}
check_runtime() {
  command -v "$QEMU" >/dev/null
  test -f "$OVMF" && test -f "$VARS_TEMPLATE" || {
    echo "Missing QEMU UEFI firmware or variables template" >&2; exit 1;
  }
}
case "$MODE" in
  check) check_iso; check_runtime; echo "VM prerequisites verified"; exit 0 ;;
  boot|install|boot-installed) ;;
  *)
    cat <<'HELP'
Usage: boot-official-iso-macos.sh check|boot|install|boot-installed
  check: verify official v0.19.0 ISO SHA256 and QEMU UEFI
  boot: read-only installer live environment, NO guest installation disk
  install: boot live ISO with a sparse local 12GiB virtio qcow2 disk
  boot-installed: boot previously installed Asterinas guest from qcow2

Environment: ASTERINAS_VM_RAM_MB=1792; ASTERINAS_VM_DISK;
ASTERINAS_VNC_DISPLAY=27; ASTERINAS_VM_NET=none|virtio-modern.
For a fresh installed-guest UEFI boot, set ASTERINAS_OVMF_VARS to a
new filename so OVMF creates a clean boot order for the explicit PCI device.
Known-good: -device virtio-blk-pci,disable-legacy=on,vectors=4.
All guest disks are files under Mac .local/archives. No Lenovo tablet or
Mac physical raw disks are passed to QEMU.
Note: the LIVE installer uses Linux; verify Asterinas itself only after
installing to the virtual disk and rebooting via 'boot-installed'.
HELP
    exit 0 ;;
esac
check_runtime
if [ "$MODE" != boot-installed ]; then check_iso; fi
if [ "$MODE" = install ] && [ ! -e "$DISK" ]; then
  qemu-img create -f qcow2 "$DISK" 12G
fi
if [ "$MODE" = boot-installed ] && [ ! -f "$DISK" ]; then
  echo "Virtual disk has not been created: $DISK" >&2; exit 1
fi
test -f "$VARS" || cp "$VARS_TEMPLATE" "$VARS"
args=(-machine q35,accel=tcg -cpu max -smp 2 -m "$MEM"
  -drive "if=pflash,format=raw,readonly=on,file=$OVMF"
  -drive "if=pflash,format=raw,file=$VARS"
  -vga std -display "vnc=127.0.0.1:$PORT"
  -serial "file:$LOG" -monitor none
  -no-reboot)
case "$MODE" in
  boot)
    args+=(-nic user,model=virtio-net-pci
           -drive "file=$ISO,media=cdrom,readonly=on,format=raw" -boot order=d)
    ;;
  install)
    args+=(-nic user,model=virtio-net-pci
           -drive "file=$ISO,media=cdrom,readonly=on,format=raw"
           -drive "file=$DISK,format=qcow2,if=virtio" -boot order=d)
    ;;
  boot-installed)
    args+=(-drive "if=none,id=u0,file=$DISK,format=qcow2"
           -device "virtio-blk-pci,drive=u0,disable-legacy=on,disable-modern=off,vectors=4" -boot order=c)
    # Upstream Asterinas v0.19.0 currently panics when probing a VirtIO PCI
    # device without an MSI-X capability. Avoid the optional default VirtIO
    # network device while isolating VirtIO block startup.
    case "$GUEST_NET" in
      none) args+=(-nic none) ;;
      virtio-modern)
        args+=(-netdev "user,id=net59,hostfwd=tcp:127.0.0.1:22259-:22"
               -device "virtio-net-pci,netdev=net59,disable-legacy=on,disable-modern=off,vectors=4")
        ;;
      *) echo "Unsupported ASTERINAS_VM_NET=$GUEST_NET" >&2; exit 1 ;;
    esac
    ;;
esac
echo "Asterinas ISO lab $MODE. VNC vnc://127.0.0.1:$((5900+PORT))"
echo "VM serial log: $LOG"
echo "VM disk (if attached): $DISK"
exec "$QEMU" "${args[@]}"
