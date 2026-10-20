#!/usr/bin/env bash
# Read-only Flick CPU/log throughput sampler; run on the NixOS tablet.
# Usage: bash tools/measure-flick-runtime.sh [1..60 seconds]
set -euo pipefail

seconds="${1:-5}"
if [[ ! "$seconds" =~ ^([1-9]|[1-5][0-9]|60)$ ]]; then
  echo "Usage: $0 [seconds 1..60]" >&2
  exit 2
fi
pid="$(systemctl show flick -P MainPID)"
if [[ ! "$pid" =~ ^[1-9][0-9]*$ ]] || [[ ! -r "/proc/$pid/stat" ]]; then
  echo "Flick is not running or /proc is unavailable" >&2
  exit 1
fi
log_dir="${FLICK_LOG_DIR:-/home/alex/.local/state/flick}"
log_file="$(find "$log_dir" -maxdepth 1 -type f -name 'compositor.log.*' -print 2>/dev/null | sort | tail -1)"
if [[ -z "$log_file" ]]; then
  echo "No dated compositor.log file in $log_dir" >&2
  exit 1
fi

# /proc/PID/stat's second field is (comm); strip it before extracting
# utime/stime fields 14 and 15 of the original proc-stat format.
cpu_ticks() {
  sed 's/^.*) //' "/proc/$pid/stat" | awk '{print $12 + $13}'
}
clock_ticks="$(getconf CLK_TCK)"
before_bytes="$(stat -c %s "$log_file")"
before_ticks="$(cpu_ticks)"
before_time="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
sleep "$seconds"
if [[ ! -r "/proc/$pid/stat" ]]; then
  echo "Flick PID changed during sample; measurement aborted" >&2
  exit 1
fi
after_bytes="$(stat -c %s "$log_file")"
after_ticks="$(cpu_ticks)"
if (( after_bytes < before_bytes )); then
  echo "Log rotated/truncated during interval; rerun sample" >&2
  exit 1
fi

echo "sample_utc=$before_time"
echo "sample_seconds=$seconds"
echo "flick_pid=$pid"
echo "flick_log=$log_file"
echo "log_bytes_start=$before_bytes"
echo "log_bytes_end=$after_bytes"
echo "log_bytes_delta=$((after_bytes - before_bytes))"
awk -v diff="$((after_bytes - before_bytes))" -v t="$seconds" \
  'BEGIN {printf "log_bytes_per_second=%.1f\n", diff / t}'
awk -v first="$before_ticks" -v last="$after_ticks" -v hz="$clock_ticks" -v t="$seconds" \
  'BEGIN {printf "flick_cpu_percent_one_core=%.1f\n", 100 * (last - first) / (hz * t)}'
ps -p "$pid" -o pid,rss,%cpu,etime,comm
echo 'recent_render_log_lines:'
tail -5 "$log_file" | cut -c1-170
