#!/usr/bin/env bash
# Disposable, unprivileged Wayland server A/B; NEVER connects to Flick's socket.
# Call on tablet, not while capturing an uncontaminated idle baseline.
set -euo pipefail
root=/run/user/$(id -u)
python=/nix/store/h097imm3w6dpx10qynrd2sz9fks2wbq8-python3-3.12.11/bin/python3
egl=/nix/store/7227amwg7k4sbl6mhglq17v5x5ki54ks-libglvnd-1.7.0/lib/libEGL.so.1
gbm=/nix/store/wilz94hzz4q3fss6qvv625zvww4a6s4s-mesa-libgbm-25.0.1/lib/libgbm.so.1
wayland=/nix/store/60lzwimi95ls10zwqxpb6ngzax1z7s9a-wayland-1.23.1/lib/libwayland-server.so.0
eglinfo=/nix/store/4aa2kcayy51d9x2zrj5ps29ci12vlc1f-mesa-demos-9.0.0/bin/eglinfo
wl_info=/nix/store/lpgrrcqq06qqi0w6vpwj9iln2hzzin6n-wayland-utils-1.2.0/bin/wayland-info
script="$HOME/lenovo-mvp/builds/.private-wl-drm-egl-probe.py"
test -r "$script"
test -r "$egl"
test -r "$gbm"
test -r "$wayland"
test -x "$python"
for mode in unbound bound; do
  runtime="$root/private-wl-drm-probe-$mode-$$"
  if [ "$mode" = bound ]; then bind=--bind; else bind=; fi
  "$python" -u "$script" --egl-lib "$egl" --gbm-lib "$gbm" \
      --wayland-lib "$wayland" --runtime "$runtime" \
      --socket egl-private --seconds 22 $bind > "$root/private-wl-drm-probe-$mode.log" 2>&1 &
  pid=$!
  echo "mode=$mode server_pid=$pid"
  ready=no
  for i in $(seq 1 30); do
    if [ -S "$runtime/egl-private" ]; then ready=yes; break; fi
    if ! kill -0 "$pid" 2>/dev/null; then break; fi
    sleep 0.2
  done
  echo "mode=$mode socket_ready=$ready"
  if [ "$ready" = yes ]; then
    echo "mode=$mode registry_interfaces"
    XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY=egl-private timeout 8 "$wl_info" 2>&1 | grep 'interface: ' || true
    echo "mode=$mode Wayland_EGL_renderer"
    # EGL init is EXPECTED to fail on an unbound control socket; do not abort.
    # SIGPIPE from head is not itself a failure of the EGL transport test.
    XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY=egl-private EGL_PLATFORM=wayland timeout 15 "$eglinfo" -B 2>&1 | sed -n '/^Wayland platform:/,/^X11 platform:/p' | head -28 || true
  fi
  wait "$pid" || true
  echo "mode=$mode server_log"
  cat "$root/private-wl-drm-probe-$mode.log"
  rm -f "$root/private-wl-drm-probe-$mode.log"
done
echo "real_flick_main_pid=$(systemctl show flick -P MainPID)"
echo "real_flick_status=$(systemctl is-active flick)"
echo "PRIVATE_COMPARISON_COMPLETE=yes"
