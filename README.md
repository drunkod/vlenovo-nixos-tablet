# vlenovo NixOS tablet

A standalone copy of the working `vlenovo` NixOS + Sxmo configuration for the Lenovo tablet.

This repository is intentionally rooted at the old `vlenovo/` directory, so the flake is used directly from the repository root.

## Current setup

- NixOS 25.05
- x86_64 Linux target with 32-bit UEFI GRUB support
- Sxmo 1.17.1 on Sway
- NetworkManager Wi-Fi
- OpenSSH with key-only login
- Bluetooth enabled and powered at boot
- Bluetooth HID keyboard tested successfully
- Tablet Windows-logo hardware button toggles the on-screen keyboard
- Passwordless sudo for the `wheel` group

## Safe remote workflow

The recommended workflow from a Mac or other laptop is:

```bash
export VLENOVO_HOST=10.230.221.139   # update when the DHCP address changes
./bin/vlenovo build
./bin/vlenovo test
./bin/vlenovo status
```

If the test behaves correctly, make it persistent:

```bash
./bin/vlenovo switch
```

`test` changes only the running system. It does not replace the boot default, so a reboot returns to the previous boot configuration if necessary.

For the complete laptop-to-tablet development and debugging guide, see [docs/REMOTE_DEVELOPMENT.md](docs/REMOTE_DEVELOPMENT.md).

For Bluetooth keyboard pairing and recovery, see [docs/BLUETOOTH.md](docs/BLUETOOTH.md).

For the tablet Windows-logo button and on-screen keyboard mapping, see [docs/HARDWARE_BUTTONS.md](docs/HARDWARE_BUTTONS.md).

## Graphics research

The Bay Trail GPU is already accelerated by Linux `i915` + Mesa Crocus. The graphics work in this repository therefore focuses on reproducible diagnostics, upstream/backport screening, and narrowly scoped fixes rather than replacing i915 with the old Windows driver.

Start with [docs/graphics/GPU-BASELINE.md](docs/graphics/GPU-BASELINE.md) and [docs/graphics/GPU-TEST-PLAN.md](docs/graphics/GPU-TEST-PLAN.md). Firmware/VBT notes are in [docs/graphics/VBT.md](docs/graphics/VBT.md), upstream screening is in [docs/graphics/UPSTREAM.md](docs/graphics/UPSTREAM.md), the original Lenovo Windows driver is analyzed in [docs/graphics/WINDOWS-REFERENCE.md](docs/graphics/WINDOWS-REFERENCE.md), and VA-API/video findings are in [docs/graphics/MEDIA-ACCELERATION.md](docs/graphics/MEDIA-ACCELERATION.md).

On the tablet, enter the diagnostic environment with:

```bash
nix develop .#graphics
./tools/collect-gpu-state
```

GPU captures are intentionally ignored by Git because ACPI/firmware dumps may contain machine-specific data.

## Flake entry points

```bash
nixos-rebuild build --flake .#vlenovo
home-manager switch --flake .#alex@vlenovo
```

The deployment helper builds on the tablet itself. This avoids unnecessary Darwin-to-Linux cross-evaluation when developing from Apple Silicon.
