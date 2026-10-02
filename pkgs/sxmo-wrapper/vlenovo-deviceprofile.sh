#!/bin/sh
# Lenovo Miix 2 10 (DMI product 20359)
# x86 tablets have no /proc/device-tree/compatible, so NixOS explicitly sets
# SXMO_DEVICE_NAME=vlenovo for this profile.

export SXMO_MONITOR="DSI-1"
export SXMO_POWER_BUTTON="1:1:gpio-keys"
export SXMO_VOLUME_BUTTON="1:1:gpio-keys"
export SXMO_SWAY_SCALE="2"
export SXMO_LISGD_EXTRA_ARGS="-w 1920 -h 1200"
export LISGD_EDGE_SIZE="4.0"
# ELAN1001 can enumerate after the Sxmo session starts. Keep the gesture hook
# alive until udev exposes a touchscreen instead of exhausting superd retries.
export SXMO_LISGD_WAIT_FOR_TOUCHSCREEN="1"
for dev in /dev/input/event*; do
  if udevadm info -q property -n "$dev" 2>/dev/null | grep -qx "ID_INPUT_TOUCHSCREEN=1"; then
    export SXMO_LISGD_INPUT_DEVICE="$dev"
    break
  fi
done
export SXMO_MIN_BRIGHTNESS="5"
export SXMO_STATES="unlock screenoff"
export SXMO_UNLOCK_IDLE_TIME="300"
export SXMO_WORKSPACE_WRAPPING="4"
export SXMO_NO_MODEM="1"
