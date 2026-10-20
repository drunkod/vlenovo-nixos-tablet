#!/usr/bin/env bash
# Read-only Lenovo Miix 2 10 ELAN1001 kernel+GUI health gate.
set -u
fail=0
status() { printf '%s=%s\n' "$1" "$2"; }
boot="$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unavailable)"
status boot_id "$boot"
status kernel "$(uname -r)"
dev=/sys/bus/i2c/devices/i2c-ELAN1001:00
acpi=/sys/bus/acpi/devices/ELAN1001:00
driver="$(readlink -f "$dev/driver" 2>/dev/null || true)"
power="$(cat "$acpi/power_state" 2>/dev/null || echo unknown)"
status elan_driver "${driver:-unbound}"
status elan_acpi_power "$power"
link=/dev/input/by-path/first-touchscreen
touch="$(readlink -f "$link" 2>/dev/null || true)"
status touch_event "${touch:-missing}"
if [ -n "$touch" ]; then
  input="$(udevadm info -q property -n "$touch" 2>/dev/null | grep -x 'ID_INPUT_TOUCHSCREEN=1' || true)"
  if [ "$input" = 'ID_INPUT_TOUCHSCREEN=1' ]; then
    status event_identified yes
  else
    status event_identified no
    fail=1
  fi
else
  status event_identified no
  fail=1
fi
if [ "$power" != D0 ] || [ -z "$driver" ]; then fail=1; fi
for unit in flick sshd NetworkManager seatd; do
  state="$(systemctl is-active "$unit" 2>/dev/null || true)"
  status "service_$unit" "$state"
  if [ "$state" != active ]; then fail=1; fi
done
if [ -n "$touch" ]; then
  pid="$(systemctl show -P MainPID flick 2>/dev/null || true)"
  if [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; then
    if ls -l "/proc/$pid/fd" 2>/dev/null | grep -Fq " -> $touch"; then
      status flick_touch_fd open
    else
      # Direct fd access can be hidden to non-owner users; report, don't misdiagnose.
      status flick_touch_fd not_confirmed
    fi
  fi
fi
status touch_kernel_health "$(if [ "$fail" -eq 0 ]; then echo PASS; else echo FAIL; fi)"
exit "$fail"
