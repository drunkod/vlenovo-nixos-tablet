#!/usr/bin/env bash
set -u

echo "=== system ==="
uname -a
echo

echo "=== failed units ==="
systemctl --failed || true
echo

echo "=== Flick ==="
systemctl status flick --no-pager || true
echo

echo "=== DRM ==="
ls -l /dev/dri || true
for c in /sys/class/drm/card*-DSI-1; do
  [ -e "$c" ] || continue
  echo "--- $c"
  cat "$c/status" 2>/dev/null || true
  cat "$c/modes" 2>/dev/null || true
done
echo

echo "=== input ==="
grep -E 'Name=|Handlers=' /proc/bus/input/devices || true
echo

echo "=== network ==="
nmcli device status || true
ip -br addr || true
echo

echo "=== Bluetooth ==="
rfkill list || true
bluetoothctl show || true
echo

echo "=== brightness ==="
brightnessctl info || true
echo

echo "=== battery ==="
for d in /sys/class/power_supply/*; do
  [ -e "$d" ] || continue
  echo "--- $d"
  grep -H . "$d"/{type,status,capacity} 2>/dev/null || true
done
echo

echo "=== audio ==="
pactl info || true
pactl list sinks short || true
echo

echo "=== memory ==="
free -h
swapon --show
echo

echo "=== recent Flick log ==="
journalctl -u flick -b --no-pager -n 100 || true
