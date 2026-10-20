#!/usr/bin/env bash
# SYSTEMD GUARD RECOVERY: root-only script. Do not run except from an explicitly
# armed timer or during an approved emergency. It NEVER switches Nix generations.
set -euo pipefail
umask 077
OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf
ORIGINAL=/etc/systemd/system/flick.service
UNIT=flick.service
MARKER='# VLENOVO_FLICK_GPU_TRIAL=1'
if (( EUID != 0 )); then
    echo 'Rollback requires system/root privileges' >&2
    exit 77
fi
if [[ ! -e "$OVERRIDE" ]]; then
    echo 'No trial override exists; leaving working compositor unchanged'
    exit 0
fi
if [[ ! -f "$ORIGINAL" || ! -f "$OVERRIDE" || -L "$OVERRIDE" ]]; then
    echo 'Rollback refused: missing original unit or unsafe override' >&2
    exit 78
fi
if ! grep -Fxq -- "$MARKER" "$OVERRIDE"; then
    echo 'Rollback refused: file does not have the trial ownership marker' >&2
    exit 78
fi
# Removing a /run drop-in reveals the untouched permanent NixOS service.
# Restore first, reload systemd, and only then restart the compositor.
rm -- "$OVERRIDE"
systemctl daemon-reload
systemctl reset-failed "$UNIT" || true
systemctl restart "$UNIT"
systemctl is-active --quiet "$UNIT"
echo 'Known-good Flick service has been restored and is active'
