#!/bin/sh
# Physical Lenovo emergency recovery; to be installed under /run only
# when a verified Gen59 image is activated for a bounded hardware test.
# systemd-run timers do NOT inherit the interactive shell PATH.
set -eu
PATH=/run/current-system/sw/bin:/nix/var/nix/profiles/system-58-link/sw/bin:/usr/bin:/bin
export PATH
MODE="${1:-restore}"
PROFILE=/nix/var/nix/profiles/system
KNOWN=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
test -L "$PROFILE-58-link"
test "$(readlink -f "$PROFILE-58-link")" = "$KNOWN" || {
  echo "Refusing recovery: gen58 path changed" >&2; exit 1;
}
if [ "$MODE" = check ]; then
  command -v readlink >/dev/null
  command -v systemctl >/dev/null
  command -v nix-env >/dev/null
  command -v logger >/dev/null
  test -x "$PROFILE-58-link/bin/switch-to-configuration"
  echo "GEN58_ROLLBACK_PREFLIGHT_OK PATH=$PATH"
  exit 0
fi
[ "$MODE" = restore ] || { echo "Invalid rollback mode" >&2; exit 1; }
logger -t gen59-rollback "Restoring touch-proven gen58 service and profile"
# Do not hold the entire recovery indefinitely if a graphics process stalls.
timeout 30s systemctl stop lenovo-wpe-kiosk.service || logger -t gen59-rollback "WPE stop timed out; continuing recovery"
if [ "$(readlink -f "$PROFILE")" != "$KNOWN" ]; then
  nix-env -p "$PROFILE" --switch-generation 58
fi
"$PROFILE/bin/switch-to-configuration" switch
systemctl start lenovo-slint-dashboard.service
systemctl is-active --quiet lenovo-slint-dashboard.service
test "$(readlink -f /run/current-system)" = "$KNOWN"
logger -t gen59-rollback "Gen58 restoration verified"
