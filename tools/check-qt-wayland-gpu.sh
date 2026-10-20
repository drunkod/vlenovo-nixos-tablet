#!/usr/bin/env bash
# Read-only QML acceleration/Wayland protocol audit for the Lenovo tablet.
# No GPU, service, backlight, udev, NixOS or sensor settings are modified.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1001}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
echo "sample_utc=$(date -u +%FT%TZ)"

if command -v wayland-info >/dev/null 2>&1; then
    registry="$(wayland-info 2>&1)"
else
    # Nix installs a temporary shell only; it does NOT activate NixOS.
    registry="$(nix shell nixpkgs#wayland-utils --command wayland-info 2>&1)"
fi
printf '%s\n' "$registry" | grep "^interface:" || true
case "$registry" in
    *zwp_linux_dmabuf_v1*) echo "linux_dmabuf_wayland_global=PRESENT" ;;
    *) echo "linux_dmabuf_wayland_global=ABSENT" ;;
esac
case "$registry" in
    *wl_drm*) echo "wl_drm_wayland_global=PRESENT" ;;
    *) echo "wl_drm_wayland_global=ABSENT" ;;
esac

qml_pid="$(pgrep -x -o qmlscene || true)"
if [[ -n "$qml_pid" ]]; then
    echo "qmlscene_pid=$qml_pid"
    ps -p "$qml_pid" -o pid,user,rss,%cpu,etime,comm
    # Only thread names are read; avoid exposing arbitrary process env/data.
    llvmpipe_count="$(sudo -n sh -c 'for f in /proc/'"$qml_pid"'/task/*/comm; do cat "$f" 2>/dev/null || :; done' | grep -c '^llvmpipe-' || true)"
    echo "qmlscene_llvmpipe_threads=$llvmpipe_count"
    render_fds="$(sudo -n sh -c 'n=0; for fd in /proc/'"$qml_pid"'/fd/*; do v=$(readlink "$fd" 2>/dev/null || :); case "$v" in /dev/dri/renderD*) n=$((n+1));; esac; done; echo "$n"')"
    echo "qmlscene_render_node_fds=$render_fds"
fi
echo "render_node_permissions=$(stat -c '%a %U:%G' /dev/dri/renderD128)"
for service in flick sshd NetworkManager seatd; do
    echo "service_${service}=$(systemctl is-active "$service")"
done
