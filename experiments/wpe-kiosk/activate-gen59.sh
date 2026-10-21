#!/bin/sh
# Run on the Lenovo from SSH only after the full image and closure are verified.
# Usage: sudo sh activate-gen59.sh /nix/store/<exact-system> [check|activate]
# WARNING: 'activate' changes the running KMS display for <=8m.
set -eu
SYSTEM="${1:?give exact verified gen59 system store path}"
MODE="${2:-check}"
BASE=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
PROFILE=/nix/var/nix/profiles/system
case "$SYSTEM" in /nix/store/*-nixos-system-vlenovo-*) ;; *) echo 'Invalid system path' >&2; exit 1;; esac
[ "$(id -u)" -eq 0 ] || { echo 'Run as root' >&2; exit 1; }
[ "$(readlink -f /run/current-system)" = "$BASE" ] || {
  echo 'Tablet is not booted in expected gen58: refusing live switch' >&2; exit 1;
}
[ "$(readlink -f "$PROFILE-58-link")" = "$BASE" ] || {
  echo 'Golden gen58 recovery profile missing' >&2; exit 1;
}
[ -x "$SYSTEM/bin/switch-to-configuration" ] || {
  echo 'New system executable missing' >&2; exit 1;
}
[ "$(cat /sys/firmware/efi/fw_platform_size)" = 32 ]
[ "$(uname -m)" = x86_64 ]
test -e /dev/dri/card1
test -e /dev/dri/renderD128
test -e /dev/input/by-path/first-touchscreen
systemctl is-active --quiet lenovo-slint-dashboard.service
systemctl is-active --quiet seatd.service
systemctl is-active --quiet NetworkManager.service
systemctl is-active --quiet sshd.service
nix-store --verify-path "$SYSTEM"
echo "GEN59_CANDIDATE=$SYSTEM"
echo "GEN58_RECOVERY=$BASE"
if [ "$MODE" = check ]; then echo PREFLIGHT_OK; exit 0; fi
[ "$MODE" = activate ] || { echo 'Mode must be check|activate' >&2; exit 1; }
[ "$SYSTEM" != "$BASE" ] || { echo "Refusing to register gen58 again" >&2; exit 1; }
[ -x /run/lenovo-gen59-restore.sh ] || { echo 'Missing independent rollback script in /run' >&2; exit 1; }
systemd-run --unit=gen59-rollback --on-active=8m /run/lenovo-gen59-restore.sh
systemctl is-active --quiet gen59-rollback.timer
echo 'ROLLBACK_ARMED_8_MINUTES'
nix-env -p "$PROFILE" --set "$SYSTEM"
echo 'SWITCHING_TO_GEN59'
"$SYSTEM/bin/switch-to-configuration" switch
echo "ACTIVE=$(readlink -f /run/current-system)"
echo "WPE_STATE=$(systemctl is-active lenovo-wpe-kiosk.service || :)"
echo "SCENE_STATE=$(systemctl is-active lenovo-wpe-scene.service || :)"
echo 'AUTOMATIC_GEN58_RESTORE_REMAINS_ARMED'
