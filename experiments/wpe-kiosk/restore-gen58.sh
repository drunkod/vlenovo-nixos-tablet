#!/bin/sh
# Physical Lenovo emergency recovery; to be installed under /run only
# when a verified Gen59 image is activated for a bounded hardware test.
set -eu
PROFILE=/nix/var/nix/profiles/system
KNOWN=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
test -L "$PROFILE-58-link"
test "$(readlink -f "$PROFILE-58-link")" = "$KNOWN" || {
  echo "Refusing recovery: gen58 path changed" >&2; exit 1;
}
logger -t gen59-rollback "Restoring touch-proven gen58 service and profile"
systemctl stop lenovo-wpe-kiosk.service || :
if [ "$(readlink -f "$PROFILE")" != "$KNOWN" ]; then
  nix-env -p "$PROFILE" --switch-generation 58
fi
"$PROFILE/bin/switch-to-configuration" switch
systemctl start lenovo-slint-dashboard.service
systemctl is-active --quiet lenovo-slint-dashboard.service
test "$(readlink -f /run/current-system)" = "$KNOWN"
logger -t gen59-rollback "Gen58 restoration verified"
