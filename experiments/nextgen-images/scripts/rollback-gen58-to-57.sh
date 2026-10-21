#!/bin/sh
# Run as root, only from a time-limited systemd recovery timer.
set -eu
PROFILE=/nix/var/nix/profiles/system
KNOWN_NEW=/nix/store/GEN58_SYSTEM_PATH_NOT_YET_SET
KNOWN_OLD=/nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4
test "$(readlink -f /nix/var/nix/profiles/system-57-link)" = "$KNOWN_OLD"
# Guard: don't roll back if another generation was chosen meanwhile.
test "$(readlink -f "$PROFILE")" = "$KNOWN_NEW" || exit 0
/run/current-system/sw/bin/nix-env -p "$PROFILE" --switch-generation 57
/nix/var/nix/profiles/system-57-link/bin/switch-to-configuration switch
