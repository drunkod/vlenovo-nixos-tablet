#!/usr/bin/env bash
# Ubuntu Colima systemd PID1 ONLY. Checks independent systemd timer survival
# across two separate Mac -> VM command sessions, never tablet services.
set -euo pipefail
[[ "$EUID" -eq 0 && "$(cat /proc/1/comm)" == systemd && ! -e /run/current-system ]] || exit 77
. /etc/os-release
[[ "$ID" == ubuntu ]] || exit 77
phase="$1"
source_script="$(cd "$(dirname "$0")" && pwd)/flick-guard-rollback.sh"
unit=vlenovo-flick-vm-detached-probe.service
path="/run/systemd/system/$unit"
dropdir="$path.d"
override="$dropdir/90-vlenovo-gpu-trial.conf"
base=/run/vlenovo-flick-vm-detached-probe
state="$base/state"
rollback="$base/rollback.sh"
timer=vlenovo-flick-vm-detached-recovery
cleanup() {
  systemctl stop "$timer.timer" "$unit" >/dev/null 2>&1 || true
  rm -f -- "$override" "$path" "$rollback" "$state"
  rmdir "$dropdir" "$base" 2>/dev/null || true
  systemctl daemon-reload
  systemctl reset-failed "$unit" >/dev/null 2>&1 || true
}
if [[ "$phase" == cleanup ]]; then
  cleanup
  echo DETACHED_VM_SYSTEMD_TEST_CLEANED=yes
  exit 0
fi
if [[ "$phase" == arm ]]; then
  [[ ! -e "$base" && ! -e "$path" && ! -e "$dropdir" ]] || exit 44
  [[ -r "$source_script" ]] || exit 44
  install -d -m700 "$base" "$dropdir"
  python3 - "$source_script" "$rollback" "$override" "$path" "$unit" <<'PY'
from pathlib import Path
import sys
source,target,override,original,unit=sys.argv[1:]
text=Path(source).read_text()
changes={
'#!/run/current-system/sw/bin/bash':'#!/bin/bash',
'export PATH=/run/current-system/sw/bin:/usr/bin:/bin':'export PATH=/usr/bin:/bin',
'OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf':f'OVERRIDE={override}',
'ORIGINAL=/etc/systemd/system/flick.service':f'ORIGINAL={original}',
'UNIT=flick.service':f'UNIT={unit}'
}
for old,new in changes.items():
    assert text.count(old)==1
    text=text.replace(old,new,1)
Path(target).write_text(text)
PY
  chmod 700 "$rollback"
  bash -n "$rollback"
  cat > "$path" <<EOF
[Unit]
Description=Disposable root systemd detached timer recovery test
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c 'echo original > $state'
EOF
  systemctl daemon-reload
  systemctl start "$unit"
  [[ "$(cat "$state")" == original ]]
  cat > "$override" <<EOF
# VLENOVO_FLICK_GPU_TRIAL=1
[Service]
ExecStart=
ExecStart=/usr/bin/bash -c 'echo experimental > $state'
EOF
  systemctl daemon-reload
  systemctl restart "$unit"
  [[ "$(cat "$state")" == experimental ]]
  systemd-run --quiet --unit="$timer" --on-active=12s \
    --timer-property=AccuracySec=1s "$rollback"
  systemctl is-active --quiet "$timer.timer"
  echo DETACHED_SYSTEM_TIMER_ARMED=yes
  echo EXPERIMENTAL_STARTED=yes
  echo ARM_COMMAND_EXITS_BEFORE_ROLLBACK=yes
  exit 0
fi
if [[ "$phase" == verify ]]; then
  [[ -e "$path" && -d "$base" ]] || exit 45
  state_actual="$(cat "$state")"
  [[ ! -e "$override" && "$state_actual" == original ]] || { echo UNRECOVERED_STATE="$state_actual"; exit 45; }
  systemctl is-active --quiet "$unit"
  outcome="$(systemctl show "$timer.service" -P Result)"
  [[ "$outcome" == success ]] || exit 45
  echo DETACHED_SYSTEM_TIMER_RESULT="$outcome"
  echo DETACHED_KNOWN_GOOD_RESTORED=yes
  cleanup
  [[ ! -e "$path" && ! -e "$base" ]] || exit 45
  echo DETACHED_SYSTEMD_VM_ROLLBACK_TEST=PASS
  exit 0
fi
echo 'Usage: arm|verify|cleanup' >&2
exit 2
