#!/bin/sh
# Read-only RAM/graphics audit. Run on the tablet as a user with sudo -n.
set -eu
echo "=== system ==="
date -u
uname -m
readlink -f /run/current-system
free -m
echo "=== processes ==="
ps -e -o pid,comm,rss,%cpu --sort=-rss | head -18
echo "=== selected process proportional/private memory ==="
for pid in $(ps -e -o pid,comm | awk '/flick|qmlscene|lenovo-native|sway|Xorg/ {print $1}'); do
  echo "PID=$pid"
  sudo -n grep -E '^(Rss|Pss|Private_Clean|Private_Dirty|Swap):' "/proc/$pid/smaps_rollup" 2>/dev/null || :
done
echo "=== service and hardware gates ==="
systemctl is-active flick sshd NetworkManager seatd 2>/dev/null || :
find /sys/class/drm -maxdepth 2 -name status -exec sh -c 'for f do printf "%s " "$f"; cat "$f"; done' sh {} + 2>/dev/null || :
ls -l /dev/input/by-path/first-touchscreen 2>/dev/null || :
cat /sys/bus/acpi/devices/ELAN1001:00/power_state 2>/dev/null || :
echo "=== i915 errors ==="
journalctl -k -b --no-pager | grep -iE 'GPU HANG|i915.*reset|i915.*error' | tail -8 || :
