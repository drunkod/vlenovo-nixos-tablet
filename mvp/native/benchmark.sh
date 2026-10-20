#!/usr/bin/env bash
# Read-only three-second CPU/RSS snapshot for Flick, QML lockscreen and MVP.
set -euo pipefail
SSH_CONFIG="${VLENOVO_SSH_CONFIG:-$HOME/.ssh/vlenovo_config}"
REMOTE="${VLENOVO_SSH_HOST:-vlenovo}"
ssh -F "$SSH_CONFIG" -o BatchMode=yes "$REMOTE" 'bash -s' <<'REMOTE'
set -eu
flick="$(systemctl show -P MainPID flick)"
qml="$(pgrep -n -f 'qmlscene.*lockscreen/main.qml' || true)"
native="$(cat /home/alex/lenovo-mvp/native.pid 2>/dev/null || true)"
viewer="$(cat /home/alex/lenovo-mvp/viewer.pid 2>/dev/null || true)"
pids="$flick"
[ -z "$qml" ] || pids="$pids,$qml"
[ -z "$native" ] || { kill -0 "$native" 2>/dev/null && pids="$pids,$native" || true; }
[ -z "$viewer" ] || { kill -0 "$viewer" 2>/dev/null && pids="$pids,$viewer" || true; }
echo "boot_id=$(cat /proc/sys/kernel/random/boot_id)"
echo "date=$(date -u --iso-8601=seconds)"
echo "touch=$(readlink -f /dev/input/by-path/first-touchscreen 2>/dev/null || echo missing)"
top -b -n 2 -d 3 -p "$pids" | tail -29
echo SERVICES
systemctl is-active flick sshd NetworkManager
echo MEMORY
free -m | head -3
REMOTE
