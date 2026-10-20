#!/usr/bin/env bash
# Read-only CPU counters from the physical tablet, designed for SSH.
set -u
duration="${1:-1800}"
interval="${2:-15}"
if [[ ! "$duration" =~ ^[0-9]+$ || ! "$interval" =~ ^[0-9]+$ || "$duration" -lt 15 || "$interval" -lt 5 ]]; then
  echo "Usage: script duration-seconds interval-seconds" >&2
  exit 2
fi
hz="$(getconf CLK_TCK)"
flick="$(systemctl show flick -P MainPID)"
qml="$(pgrep -xo qmlscene || true)"
native="$(pgrep -xo lenovo-native-m || true)"
if [[ -z "$native" ]]; then native="$(pgrep -f -o 'lenovo-native' || true)"; fi
echo "# sample_start_utc=$(date -u +%FT%TZ)"
echo "# duration_s=$duration interval_s=$interval hz=$hz flick=$flick qml=$qml native=$native"
echo 'timestamp_utc,elapsed_s,flick_pid,flick_ticks,flick_rss_kb,qml_pid,qml_ticks,qml_rss_kb,native_pid,native_ticks,native_rss_kb,qml_llvmpipe_threads,wayland_socket,services'
read_proc() {
  local pid="$1"
  if [[ -z "$pid" || ! -r "/proc/$pid/stat" ]]; then echo "NA,NA";return;fi
  local line dat rss
  IFS= read -r line < "/proc/$pid/stat"
  dat="${line##*) }"
  local ticks
  ticks="$(awk '{print $12+$13}' <<< "$dat")"
  rss="$(awk '/VmRSS:/ {print $2}' "/proc/$pid/status" 2>/dev/null)"
  echo "$ticks,${rss:-NA}"
}
timezero="$(date +%s)"
i=0
while :; do
  now="$(date +%s)"
  elapsed=$((now-timezero))
  qthreads=0
  if [[ -n "$qml" && -d /proc/"$qml"/task ]]; then
    for f in /proc/"$qml"/task/*/comm; do
      [[ -r "$f" ]] || continue
      IFS= read -r name < "$f" || true
      [[ "$name" == llvmpipe-* ]] && qthreads=$((qthreads+1))
    done
  fi
  if [[ -S /run/user/1001/wayland-1 ]]; then sock=present; else sock=absent; fi
  if systemctl is-active --quiet flick; then services=active; else services=inactive; fi
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$elapsed" "$flick" "$(read_proc "$flick")" "$qml" "$(read_proc "$qml")" "$native" "$(read_proc "$native")" "$qthreads" "$sock" "$services"
  if (( elapsed >= duration )); then break; fi
  sleep "$interval"
done
echo "# sample_end_utc=$(date -u +%FT%TZ)"
