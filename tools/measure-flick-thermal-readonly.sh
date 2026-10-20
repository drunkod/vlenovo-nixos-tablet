#!/usr/bin/env bash
# Read-only thermal context. Never touches ALS shared sensor hub or sysfs settings.
set -euo pipefail
duration="$1"
interval="$2"
[[ "$duration" =~ ^[0-9]+$ && "$interval" =~ ^[0-9]+$ ]] || exit 2
(( duration>=60 && duration<=7200 && interval>=10 && interval<=120 )) || exit 2
echo "timestamp_utc,elapsed_s,tcpu_mc,soc0_mc,soc1_mc,cpu0_khz,cpu1_khz,cpu2_khz,cpu3_khz,ac_online,battery_percent,flick_pid"
t0=$(date +%s)
read_number() { if [[ -r "$1" ]]; then cat "$1"; else printf NA; fi; }
while :; do
 now=$(date +%s)
 elapsed=$((now-t0))
 printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(date -u +%FT%TZ)" "$elapsed" \
    "$(read_number /sys/class/thermal/thermal_zone5/temp)" \
    "$(read_number /sys/class/thermal/thermal_zone6/temp)" \
    "$(read_number /sys/class/thermal/thermal_zone7/temp)" \
    "$(read_number /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)" \
    "$(read_number /sys/devices/system/cpu/cpu1/cpufreq/scaling_cur_freq)" \
    "$(read_number /sys/devices/system/cpu/cpu2/cpufreq/scaling_cur_freq)" \
    "$(read_number /sys/devices/system/cpu/cpu3/cpufreq/scaling_cur_freq)" \
    "$(read_number /sys/class/power_supply/ADP1/online)" \
    "$(read_number /sys/class/power_supply/BATC/capacity)" \
    "$(systemctl show flick -P MainPID)"
 ((elapsed>=duration)) && break
 sleep "$interval"
done
