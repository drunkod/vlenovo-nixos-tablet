#!/bin/sh
# Read-only hardware / service verification after a bounded gen59 live activation.
set -eu
BASE=/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4
echo "UTC=$(date -u +%FT%TZ)"
echo "CURRENT=$(readlink -f /run/current-system)"
echo "PROFILE=$(readlink -f /nix/var/nix/profiles/system)"
echo "ROLLBACK_GEN58=$(readlink -f /nix/var/nix/profiles/system-58-link)"
test "$(readlink -f /nix/var/nix/profiles/system-58-link)" = "$BASE"
test "$(cat /sys/firmware/efi/fw_platform_size)" = 32
test "$(uname -m)" = x86_64
echo "KERNEL=$(uname -r)"
echo "TOUCH=$(readlink -f /dev/input/by-path/first-touchscreen)"
udevadm info -q property -n /dev/input/by-path/first-touchscreen | grep -Fx ID_INPUT_TOUCHSCREEN=1
echo "TOUCH_POWER=$(cat /sys/bus/acpi/devices/ELAN1001:00/power_state)"
printf '%s\n' 'ACTIVE_UNITS:'
systemctl is-active lenovo-wpe-kiosk lenovo-wpe-scene sshd NetworkManager seatd
systemctl show lenovo-wpe-kiosk -p MainPID -p ActiveState -p NRestarts -p Result
printf '%s\n' 'SCENE_HTTP:'
curl --max-time 4 -fsS http://127.0.0.1:17858/health
echo
printf '%s\n' 'GPU_PROCESSES:'
ps -eo pid,etime,%cpu,rss,comm,args | grep -E '(lenovo-wpe-kiosk|WebKit(Web|Network|GPU)Process)' | grep -v 'grep -E' | head -15 || :
printf '%s\n' 'DRM_DEVICES:'
ls -l /dev/dri
printf '%s\n' 'GPU_KERNEL_ERRORS:'
journalctl -k -b --no-pager | grep -Ei 'GPU HANG|i915.*reset' | tail -8 || :
printf '%s\n' 'APP_LOG:'
journalctl -b -u lenovo-wpe-kiosk --no-pager | tail -30
printf '%s\n' 'MEMORY:'
free -m
printf '%s\n' 'FAILED_UNITS:'
systemctl --failed --no-pager --no-legend | head -12
printf '%s\n' 'WATCHDOG:'
systemctl list-timers --all --no-pager | grep -E 'gen59.*rollback|gen59.*restore' || :
echo "REMOTE_GEN59_CHECKS_FINISHED: visible pixels and finger touches require a physical person"
