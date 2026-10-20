#!/usr/bin/env bash
# Independent, user-session Rust/Slint frontend, NOT a NixOS deployment.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_CONFIG="${VLENOVO_SSH_CONFIG:-$HOME/.ssh/vlenovo_config}"
REMOTE="${VLENOVO_SSH_HOST:-vlenovo}"
ssh_remote() { ssh -F "$SSH_CONFIG" -o BatchMode=yes "$REMOTE" "$@"; }
case "${1:-status}" in
    sync)
        ssh_remote 'mkdir -p /home/alex/lenovo-mvp/native'
        rsync -az --exclude target --exclude '.DS_Store' -e "ssh -F $SSH_CONFIG" "$ROOT/" "$REMOTE:lenovo-mvp/native/"
        ;;
    build)
        "$ROOT/run-on-tablet.sh" sync
        ssh_remote 'bash -s' <<'REMOTE_BUILD'
set -eu
cd /home/alex/lenovo-mvp/native
export PATH=/nix/store/gmgfpzc0w2pgby0lmq9r88m39albiyfw-cargo-1.98.1/bin:/nix/store/53lvgpxsb3b9ghkgb4v0jra6zzlnyw8n-rustc-1.98.1/bin:$PATH
export CARGO_BUILD_JOBS=2 CARGO_INCREMENTAL=0 CARGO_PROFILE_DEV_DEBUG=0
nix shell nixpkgs#stdenv.cc nixpkgs#pkg-config nixpkgs#wayland nixpkgs#libxkbcommon nixpkgs#fontconfig nixpkgs#freetype -c cargo build --locked -j 2
REMOTE_BUILD
        ;;
    start)
        ssh_remote 'bash -s' <<'REMOTE_START'
set -eu
D=/home/alex/lenovo-mvp
B=$D/native/target/debug/lenovo-native-mvp
test -x "$B" || { echo "Native binary not built; run ./run-on-tablet.sh build" >&2; exit 1; }
if [ -f "$D/native.pid" ] && kill -0 "$(cat "$D/native.pid")" 2>/dev/null; then
  echo "Native MVP already running, PID $(cat "$D/native.pid")"
  exit 0
fi
export XDG_RUNTIME_DIR=/run/user/1001
export WAYLAND_DISPLAY=wayland-1
export SLINT_BACKEND=winit-software
export FONTCONFIG_FILE=/etc/fonts/fonts.conf
export LD_LIBRARY_PATH=/nix/store/nm07kfl411ig0yv61rvginj665b6c0ms-fontconfig-2.16.0-lib/lib:/nix/store/3plshrvvh0hxxvqgd0r3bpkm5475w7d0-freetype-2.13.3/lib:/nix/store/h64w118vqfw706px8ranz6cx07ki06jl-wayland-1.23.1/lib:/nix/store/dxh4x7x96lfadv500bdw3m2b3h4a3vwa-libxkbcommon-1.10.0/lib
nohup "$B" > "$D/native.log" 2>&1 < /dev/null &
echo "$!" > "$D/native.pid"
sleep 2
kill -0 "$(cat "$D/native.pid")" || { cat "$D/native.log"; exit 1; }
echo "Rust/Slint native MVP running, PID $(cat "$D/native.pid")"
REMOTE_START
        ;;
    status)
        ssh_remote 'bash -s' <<'REMOTE_STATUS'
set -eu
D=/home/alex/lenovo-mvp
if [ -f "$D/native.pid" ]; then
  p="$(cat "$D/native.pid")"
  ps -p "$p" -o pid,rss,%cpu,etime,args || true
fi
systemctl is-active flick sshd NetworkManager
test ! -f "$D/native.log" || tail -8 "$D/native.log"
test ! -f "$D/native-events.tsv" || tail -8 "$D/native-events.tsv"
REMOTE_STATUS
        ;;
    stop)
        ssh_remote 'bash -s' <<'REMOTE_STOP'
set -eu
D=/home/alex/lenovo-mvp
if [ ! -f "$D/native.pid" ]; then echo 'No PID file'; exit 0; fi
p="$(cat "$D/native.pid")"
if ps -p "$p" -o args= 2>/dev/null | grep -F -q "$D/native/target/debug/lenovo-native-mvp"; then
  kill "$p"
  echo "Stopped native MVP PID $p"
else
  echo "Process absent or PID mismatch; no signal sent"
fi
REMOTE_STOP
        ;;
    *) echo "Usage: $0 {sync|build|start|status|stop}" >&2; exit 2;;
esac
