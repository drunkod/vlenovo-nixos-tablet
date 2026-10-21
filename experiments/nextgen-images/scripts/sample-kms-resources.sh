#!/bin/sh
# Read-only 60-second measurement for Slint direct KMS across variants.
# Restrict output to aggregate numeric process/system metrics, not secrets.
set -eu
COUNT="${1:-12}"
INTERVAL="${2:-5}"
printf 'timestamp_utc,available_mib,slint_pss_kib,slint_anon_kib,slint_rss_kib,drm_sys_kib,slint_cpu_pct,nrestarts\n'
i=0
while [ "$i" -lt "$COUNT" ]; do
  p=$(systemctl show lenovo-slint-dashboard -p MainPID --value)
  [ "$p" -gt 1 ] || exit 1
  avail=$(awk '/^MemAvailable:/ {printf "%d", $2/1024}' /proc/meminfo)
  smaps=$(sudo -n cat "/proc/$p/smaps_rollup")
  pss=$(printf '%s\n' "$smaps" | awk '$1=="Pss:" {print $2}')
  anon=$(printf '%s\n' "$smaps" | awk '$1=="Pss_Anon:" {print $2}')
  rss=$(printf '%s\n' "$smaps" | awk '$1=="Rss:" {print $2}')
  drm=$(sudo -n sh -c "grep -h '^drm-total-system0:' /proc/$p/fdinfo/* 2>/dev/null" | awk '{if($2>max)max=$2}END {print max+0}')
  cpu=$(ps -p "$p" -o %cpu= | tr -d ' ')
  restarts=$(systemctl show lenovo-slint-dashboard -p NRestarts --value)
  printf '%s,%s,%s,%s,%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$avail" "$pss" "$anon" "$rss" "$drm" "$cpu" "$restarts"
  i=$((i+1))
  [ "$i" -ge "$COUNT" ] || sleep "$INTERVAL"
done
