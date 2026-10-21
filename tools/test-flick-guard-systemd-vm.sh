#!/usr/bin/env bash
# ROOT ONLY *inside dedicated Linux VM*. Real SYSTEM-manager rollback.
# Never run on NixOS tablet or any production machine.
set -euo pipefail
[[ "$EUID" == 0 ]] || { echo 'Requires isolated VM root' >&2; exit 77; }
[[ "$(cat /proc/1/comm)" == systemd ]] || { echo 'Requires Linux VM systemd PID1' >&2; exit 77; }
[[ ! -e /run/current-system ]] || { echo 'Refuse on NixOS; this test is VM-only' >&2; exit 77; }
[[ -f /etc/os-release ]] && . /etc/os-release
[[ "$ID" == ubuntu ]] || { echo 'Refuse non-Ubuntu system' >&2; exit 77; }
[[ -e /run/systemd/system ]] || exit 77

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source_script="$SCRIPT_DIR/flick-guard-rollback.sh"
[[ -r "$source_script" ]] || { echo 'Original rollback logic unavailable' >&2; exit 2; }
unit_name=vlenovo-flick-vm-guard-probe.service
unit="/run/systemd/system/$unit_name"
dropdir="/run/systemd/system/$unit_name.d"
override="$dropdir/90-vlenovo-gpu-trial.conf"
base=/run/vlenovo-flick-vm-guard-probe
state="$base/state"
runner="$base/rollback.sh"
timer_name=vlenovo-flick-vm-guard-timer
[[ ! -e "$unit" && ! -e "$dropdir" && ! -e "$base" ]] || {
 echo 'Existing probe state found; refusing to overwrite' >&2; exit 4;
}
cleanup() {
  systemctl stop "$timer_name.timer" "$unit_name" >/dev/null 2>&1 || true
  rm -f -- "$override" "$unit" "$runner" "$state"     "$base/no-override.log" "$base/unmarked.log" "$base/symlink.log"
  rmdir "$dropdir" "$base" >/dev/null 2>&1 || true
  systemctl daemon-reload >/dev/null
  systemctl reset-failed "$unit_name" >/dev/null 2>&1 || true
}
trap cleanup EXIT
install -d -m700 "$base" "$dropdir"
python3 - "$source_script" "$runner" "$override" "$unit" "$unit_name" <<'PY'
from pathlib import Path
import sys
src,dest,override,original,unit=sys.argv[1:]
s=Path(src).read_text()
originals={
'#!/run/current-system/sw/bin/bash':'#!/bin/bash',
'export PATH=/run/current-system/sw/bin:/usr/bin:/bin':'export PATH=/usr/bin:/bin',
'OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf':f'OVERRIDE={override}',
'ORIGINAL=/etc/systemd/system/flick.service':f'ORIGINAL={original}',
'UNIT=flick.service':f'UNIT={unit}',
}
for key,val in originals.items():
    assert s.count(key)==1, f"Expected exact recovery source pattern: {key}"
    s=s.replace(key,val,1)
Path(dest).write_text(s)
PY
chmod 700 "$runner"
bash -n "$runner"
cat > "$unit" <<EOF
[Unit]
Description=Disposable VM-only SYSTEM-level rollback rehearsal
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/bash -c 'echo original > $state'
EOF
systemctl daemon-reload
systemctl start "$unit_name"
[[ "$(cat "$state")" == original ]] || exit 8
echo "SYSTEM_LEVEL_ORIGINAL=PASS"
"$runner" > "$base/no-override.log"
[[ "$(cat "$state")" == original ]] || exit 8
echo "NO_OVERRIDE_SAFE=PASS"
cat > "$override" <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/bash -c 'echo experimental > $state'
EOF
set +e
"$runner" > "$base/unmarked.log" 2>&1
unmarked_rc=$?
set -e
[[ "$unmarked_rc" -eq 78 && -e "$override" ]] || { echo "UNMARKED_REFUSAL_FAILED=$unmarked_rc"; exit 8; }
echo "UNMARKED_OVERRIDE_REFUSED=PASS"
rm -- "$override"
ln -s "$unit" "$override"
set +e
"$runner" > "$base/symlink.log" 2>&1
symlink_rc=$?
set -e
[[ "$symlink_rc" -eq 78 && -L "$override" ]] || { echo "SYMLINK_REFUSAL_FAILED=$symlink_rc"; exit 8; }
echo "SYMLINK_OVERRIDE_REFUSED=PASS"
rm -- "$override"
cat > "$override" <<EOF
# VLENOVO_FLICK_GPU_TRIAL=1
[Service]
ExecStart=
ExecStart=/usr/bin/bash -c 'echo experimental > $state'
EOF
systemctl daemon-reload
systemctl restart "$unit_name"
[[ "$(cat "$state")" == experimental ]] || exit 8
echo "SYSTEM_LEVEL_EXPERIMENTAL=PASS"
systemd-run --quiet --unit="$timer_name" --on-active=8s \
  --timer-property=AccuracySec=1s "$runner"
systemctl is-active --quiet "$timer_name.timer"
echo "SYSTEM_LEVEL_SYSTEMD_TIMER_ARMED=PASS"
success=no
for _ in $(seq 1 32); do
  if [[ ! -e "$override" ]] && [[ "$(cat "$state")" == original ]] &&
     systemctl is-active --quiet "$unit_name"; then
    success=yes; break
  fi
  sleep 1
done
[[ "$success" == yes ]] || {
  echo 'SYSTEM_LEVEL_RECOVERY_FAILED'; systemctl status "$timer_name.service" --no-pager || true
  exit 8
}
echo "SYSTEM_LEVEL_TIMER_RESTORED_ORIGINAL=PASS"
echo "TIMER_RESULT=$(systemctl show "$timer_name.service" -P Result)"
echo "AFTER_UNIT_STATE=$(systemctl is-active "$unit_name")"
echo "TEST_VM_SYSTEM_MANAGER_ROLLBACK=PASS"
