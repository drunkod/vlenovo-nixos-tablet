#!/bin/sh
# One-shot on physical gen58: temporarily run experimental Slint, and restore
# the exact stable gen58 service. Never edits /nix profiles or GRUB.
set -eu
NEW=/nix/store/5i83bdnpvfnn81bcs8x6ij44iidc952m-lenovo-slint-kms-gpu-0.1.0/bin/lenovo-native-mvp
GEN58=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
SERVICE=lenovo-slint-dashboard.service
TIMER=vlenovo-lowram-restore
test "$(readlink -f /run/current-system)" = "$GEN58"
test -x "$NEW"
systemctl is-active --quiet "$SERVICE"
systemctl is-active --quiet seatd.service
printf '#!/bin/sh\nexec /run/current-system/sw/bin/systemctl start lenovo-slint-dashboard.service\n' | sudo -n tee /run/vlenovo-lowram-restore.sh >/dev/null
sudo -n chmod 700 /run/vlenovo-lowram-restore.sh
sudo -n systemd-run --unit="$TIMER" --on-active=90s /run/vlenovo-lowram-restore.sh
restore() {
  sudo -n systemctl start "$SERVICE" || :
  if systemctl is-active --quiet "$SERVICE"; then sudo -n systemctl stop "$TIMER.timer" || :; fi
}
trap restore EXIT INT TERM
sudo -n systemctl stop "$SERVICE"
sudo -n -u alex env HOME=/home/alex FONTCONFIG_FILE=/etc/fonts/fonts.conf \
  LIBSEAT_BACKEND=seatd SLINT_BACKEND=linuxkms-femtovg SLINT_DRM_OUTPUT=DSI-1 \
  LD_LIBRARY_PATH=/nix/store/7227amwg7k4sbl6mhglq17v5x5ki54ks-libglvnd-1.7.0/lib:/nix/store/wilz94hzz4q3fss6qvv625zvww4a6s4s-mesa-libgbm-25.0.1/lib:/run/opengl-driver/lib \
  LIBGL_DRIVERS_PATH=/run/opengl-driver/lib/dri \
  GBM_BACKENDS_PATH=/run/opengl-driver/lib/gbm MESA_LOADER_DRIVER_OVERRIDE=crocus \
  timeout 30s "$NEW" >/tmp/lenovo-lowram-trial.out 2>/tmp/lenovo-lowram-trial.err &
job=$!
sleep 8
pid=''
for cand in $(pgrep -u alex -f lenovo-native 2>/dev/null || :); do
  exe=$(readlink -f "/proc/$cand/exe" 2>/dev/null || :)
  case "$exe" in /nix/store/5i83bdnpvfnn81bcs8x6ij44iidc952m-lenovo-slint-kms-gpu-0.1.0/*) pid="$cand"; break;; esac
done
if [ -n "$pid" ]; then
  echo "TRIAL_PID=$pid"
  sudo -n grep -E '^(Rss|Pss|Pss_Anon|Pss_File|Private_Dirty|Swap):' "/proc/$pid/smaps_rollup"
  ps -p "$pid" -o pid,etime,%cpu,rss
  sudo -n cat "/proc/$pid/fdinfo/5" | grep -E '^drm-(driver|total-system0):' || :
  echo "TRIAL_MEM_AVAILABLE_MIB=$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)"
else
  echo "TRIAL_PROCESS_NOT_FOUND"
fi
sleep 13
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  echo "TRIAL_21S"
  sudo -n grep -E '^(Rss|Pss|Pss_Anon|Pss_File|Private_Dirty):' "/proc/$pid/smaps_rollup"
  sudo -n cat "/proc/$pid/fdinfo/5" | grep -E '^drm-(driver|total-system0):' || :
fi
sleep 6
if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
  echo "TRIAL_27S"
  sudo -n grep -E '^(Rss|Pss|Pss_Anon|Pss_File|Private_Dirty):' "/proc/$pid/smaps_rollup"
  sudo -n cat "/proc/$pid/fdinfo/5" | grep -E '^drm-(driver|total-system0):' || :
fi
wait "$job" || rc=$?
echo "APP_TIMEOUT_RC=${rc:-0}"
cat /tmp/lenovo-lowram-trial.err | tail -15
sudo -n systemctl start "$SERVICE"
sleep 2
systemctl show "$SERVICE" -p ActiveState -p MainPID -p NRestarts
echo "RESTORED_GEN58"
