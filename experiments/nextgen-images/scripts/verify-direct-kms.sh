#!/bin/sh
# Read-only checks on physical Miix after a Slint direct KMS activation.
set -eu
printf '%s\n' '=== booted generation and system health ==='
date -u
readlink -f /run/current-system
readlink -f /nix/var/nix/profiles/system
test "$(readlink -f /run/current-system)" = "/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4"
test "$(readlink -f /run/current-system)" = "$(readlink -f /nix/var/nix/profiles/system)"
test "$(cat /sys/firmware/efi/fw_platform_size)" = 32
systemctl is-active lenovo-slint-dashboard sshd NetworkManager seatd
test "$(systemctl show lenovo-slint-dashboard -p NRestarts --value)" = 0
systemctl is-system-running
printf '%s\n' '=== compositor absent ==='
if systemctl is-active --quiet flick.service; then echo 'FAIL: Flick is still running'; exit 1; fi
printf '%s\n' '=== touchscreen ==='
test "$(cat /sys/bus/acpi/devices/ELAN1001:00/power_state)" = D0
test -e /dev/input/by-path/first-touchscreen
device=$(readlink -f /dev/input/by-path/first-touchscreen)
echo "touch device: $device"
udevadm info -q property -n "$device" | grep -Fx 'ID_INPUT_TOUCHSCREEN=1'
id -nG alex | tr ' ' '\n' | grep -Fx 'seat'
printf '%s\n' '=== Rust display process ==='
pid=$(systemctl show lenovo-slint-dashboard -p MainPID --value)
test "$pid" -gt 1
echo "PID=$pid"
printf '%s\n' '=== DRM GPU and touchscreen file descriptors ==='
sudo -n ls -l "/proc/$pid/fd" | grep -E '/dev/dri/card[0-9]+'
sudo -n ls -l "/proc/$pid/fd" | grep -F "$device"
printf '%s\n' '=== Mesa Gallium GBM and EGL runtime ==='
sudo -n grep -E "(libgallium|libEGL_mesa|dri_gbm.so)" "/proc/$pid/maps" | head -4
systemctl show lenovo-slint-dashboard -p Environment | grep -F "MESA_LOADER_DRIVER_OVERRIDE=crocus"
printf '%s\n' '=== Slint FemtoVG OpenGL startup ==='
journalctl -b --no-pager | grep -F "Using FemtoVG OpenGL renderer" | tail -1
journalctl -b --no-pager | grep -F "Rendering at 1920x1200" | tail -1
printf '%s\n' '=== memory and service activity ==='
sudo -n grep -E '^(Rss|Pss|Private_Clean|Private_Dirty|Swap):' "/proc/$pid/smaps_rollup" || :
ps -p "$pid" -o pid,comm,etime,%cpu,rss
free -m
printf '%s\n' '=== possible GPU hang ==='
journalctl -k -b --no-pager | grep -Ei 'GPU HANG|i915.*reset' | tail -4 || :
printf '%s\n' 'REMOTE_CHECKS_PASSED (physical finger taps and visible pixels still need confirmation)'
