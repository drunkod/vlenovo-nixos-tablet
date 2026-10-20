#!/usr/bin/env bash
# Disposable unprivileged systemd rehearsal on the tablet. NEVER touches Flick.
set -euo pipefail
umask 077
phase="${1:-}"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export XDG_RUNTIME_DIR="$runtime"
base="$runtime/vlenovo-flick-guard-probe"
name="vlenovo-flick-guard-probe.service"
unit="$runtime/systemd/user/$name"
dropdir="$runtime/systemd/user/$name.d"
override="$dropdir/90-vlenovo-gpu-trial.conf"
timer="vlenovo-flick-guard-probe-timer-v2"
original_script="$HOME/lenovo-mvp/builds/.guard-recovery-original.sh"
run_script="$base/rollback.sh"
state="$base/state"
cleanup() {
  systemctl --user stop "$timer.timer" "$name" >/dev/null 2>&1 || true
  rm -f -- "$override" "$unit" "$run_script" "$state" "$base/live-flick-pid" "$original_script"
  rmdir "$dropdir" "$base" >/dev/null 2>&1 || true
  systemctl --user daemon-reload
}
if [[ "$phase" == cleanup ]]; then
  cleanup
  echo 'USER_SYSTEMD_REHEARSAL_CLEANED'
  exit 0
fi
if [[ "$phase" == setup ]]; then
  [[ -f "$original_script" ]] || { echo 'original rollback script not staged' >&2; exit 2; }
  [[ ! -e "$unit" && ! -e "$override" ]] || { echo 'probe already exists' >&2; exit 2; }
  mkdir -p "$base" "$dropdir"
  systemctl show flick -P MainPID > "$base/live-flick-pid"
  sed \
    -e "s|^OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf$|OVERRIDE=$override|" \
    -e "s|^ORIGINAL=/etc/systemd/system/flick.service$|ORIGINAL=$unit|" \
    -e "s|^UNIT=flick.service$|UNIT=$name|" \
    -e 's|if (( EUID != 0 )); then|if (( EUID == 0 )); then|' \
    -e 's|^systemctl |systemctl --user |' \
    "$original_script" > "$run_script"
  chmod 0700 "$run_script"
  bash -n "$run_script"
  cat > "$unit" <<EOF
[Unit]
Description=Disposable unprivileged graphics rollback rehearsal
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/run/current-system/sw/bin/bash -c 'echo original > $state'
EOF
  systemctl --user daemon-reload
  systemctl --user start "$name"
  [[ "$(cat "$state")" == original ]] || { echo 'dummy original not started' >&2; exit 3; }
  cat > "$override" <<EOF
# VLENOVO_FLICK_GPU_TRIAL=1
[Service]
ExecStart=
ExecStart=/run/current-system/sw/bin/bash -c 'echo experimental > $state'
EOF
  systemctl --user daemon-reload
  systemctl --user restart "$name"
  [[ "$(cat "$state")" == experimental ]] || { echo 'dummy experimental not active' >&2; exit 3; }
  systemd-run --user --quiet --unit="$timer" --on-active=8s --timer-property=AccuracySec=1s "$run_script"
  systemctl --user is-active --quiet "$timer.timer"
  echo 'USER_TIMER_ARMED=8s'
  echo "DUMMY_BEFORE_TIMER=$(cat "$state")"
  echo "FLICK_PID_BEFORE=$(cat "$base/live-flick-pid")"
  exit 0
fi
if [[ "$phase" == verify ]]; then
  success=no
  for i in $(seq 1 20); do
    if [[ ! -e "$override" ]] && [[ -r "$state" ]] && [[ "$(cat "$state")" == original ]]; then
      success=yes
      break
    fi
    sleep 1
  done
  echo "RECOVERY_RESULT=$success"
  echo "DUMMY_AFTER_TIMER=$(cat "$state" 2>/dev/null || echo missing)"
  echo "FLICK_PID_AFTER=$(systemctl show flick -P MainPID)"
  [[ "$success" == yes && "$(systemctl show flick -P MainPID)" == "$(cat "$base/live-flick-pid")" ]]
  echo "TIMER_SERVICE_RESULT=$(systemctl --user show "$timer.service" -P Result)"
  echo "DUMMY_SERVICE_STATE=$(systemctl --user is-active "$name")"
  cleanup
  echo 'USER_SYSTEMD_INTEGRATION=PASS'
  exit 0
fi
echo 'Usage: script setup|verify|cleanup' >&2
exit 2
