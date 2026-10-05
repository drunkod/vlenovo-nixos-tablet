# Flick Stage 2 Working Checkpoint

Date: 2026-10-05

## Known-good NixOS generations

- Generation 54: Flick graphical session, booted/current/profile
- Generation 52: SXMO/Sway recovery generation

## Validated boot/runtime chain

- Linux kernel: 6.12.36
- Flick backend: native DRM/KMS udev backend
- seatd/libseat: active, seat0 acquired on first service start
- DRM device selected by Flick: /dev/dri/card1
- Internal panel: DSI-1
- Display mode: 1920x1200@60
- Flick service: active, NRestarts=0, ExecMainStatus=0
- SXMO service: inactive in the Flick generation
- SSH: active after boot
- NetworkManager: active after boot
- Wi-Fi: connected after boot
- PulseAudio: active
- Backlight device: intel_backlight
- Failed systemd units: 0

## Known non-blocking warning

The kernel logs i915 Failed to own gpio for panel control during boot. It does not prevent DRM initialization, DSI modesetting, or Flick rendering and is not treated as a Stage 2 blocker.

## Evidence files

- flick-boot.log: generation-54 Flick journal for this boot
- flick-service.log: systemd status for Flick
- hardware-acceptance.txt: output of tests/flick-hardware.sh
- nixos-generations.txt: system profile generations at checkpoint time

## Recovery

Generation 52 remains the SXMO/Sway rollback point. SSH and NetworkManager are the primary recovery plane.
