#!/usr/bin/env bash
# Run a non-invasive Slint demo as a Wayland client on the active Flick compositor.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="${VLENOVO_SSH_CONFIG:-$HOME/.ssh/vlenovo_config}"
REMOTE="${VLENOVO_SSH_HOST:-vlenovo}"
ssh_remote() { ssh -F "$SSH_CONFIG" -o BatchMode=yes "$REMOTE" "$@"; }
action="${1:-status}"
case "$action" in
  start)
    ssh_remote 'mkdir -p /home/alex/lenovo-mvp'
    scp -q -F "$SSH_CONFIG" "$ROOT/TabletMvp.slint" "$ROOT/handle-action.sh" "$REMOTE:lenovo-mvp/"
    ssh_remote 'bash -s' <<'REMOTE_START'
set -euo pipefail
D=/home/alex/lenovo-mvp
chmod +x "$D/handle-action.sh"
if [ -s "$D/viewer.pid" ] && kill -0 "$(cat "$D/viewer.pid")" 2>/dev/null; then
    echo "MVP is already running with PID $(cat "$D/viewer.pid")."
    exit 0
fi
VIEWER=/nix/store/2y4ybk2dg10bna8bzddhjzi1hkgkf2vi-slint-viewer-1.11.0/bin/slint-viewer
if [ ! -x "$VIEWER" ]; then
    nix build --no-link --option max-jobs 2 nixpkgs#slint-viewer
    VIEWER="$(nix eval --raw nixpkgs#slint-viewer.outPath)/bin/slint-viewer"
fi
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=wayland-1
# Winit dynamically loads Wayland/XKB; these library paths were verified on this tablet.
export LD_LIBRARY_PATH=/nix/store/h64w118vqfw706px8ranz6cx07ki06jl-wayland-1.23.1/lib:/nix/store/dxh4x7x96lfadv500bdw3m2b3h4a3vwa-libxkbcommon-1.10.0/lib
nohup "$VIEWER" --backend winit-software --on test-event '/home/alex/lenovo-mvp/handle-action.sh "$1"' "$D/TabletMvp.slint" > "$D/viewer.log" 2>&1 < /dev/null &
echo "$!" > "$D/viewer.pid"
sleep 2
kill -0 "$(cat "$D/viewer.pid")"
echo "MVP launched (PID $(cat "$D/viewer.pid")), no system activation."
REMOTE_START
    ;;
  status)
    ssh_remote 'bash -s' <<'REMOTE_STATUS'
set -e
D=/home/alex/lenovo-mvp
if [ -s "$D/viewer.pid" ]; then
  pid="$(cat "$D/viewer.pid")"
  ps -p "$pid" -o pid,rss,%cpu,etime,comm || true
fi
systemctl is-active flick
free -h | head -3
if [ -e "$D/viewer.log" ]; then tail -5 "$D/viewer.log"; fi
REMOTE_STATUS
    ;;
  stop)
    ssh_remote 'bash -s' <<'REMOTE_STOP'
set -e
D=/home/alex/lenovo-mvp
if [ ! -s "$D/viewer.pid" ]; then echo 'MVP not running'; exit 0; fi
pid="$(cat "$D/viewer.pid")"
if ps -p "$pid" -o args= 2>/dev/null | grep -F -q '/lenovo-mvp/TabletMvp.slint'; then
    kill "$pid"
    echo "Stopped MVP PID $pid"
else
    echo "PID $pid is not the expected MVP, refusing to signal it"
fi
REMOTE_STOP
    ;;
  *) echo "Usage: $0 start|status|stop" >&2; exit 2 ;;
esac
