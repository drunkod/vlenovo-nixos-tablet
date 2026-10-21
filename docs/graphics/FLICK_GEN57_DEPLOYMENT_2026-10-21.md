# Lenovo tablet: NixOS generation 57 installed and boot verified

Date: 2026-10-21. Branch: `flick-gpu-optimization`.

## Installation result

**SUCCESS:** generation 57 installed on the physical Lenovo Miix 2 10, activated, and booted after one controlled restart.

- Generation 56 (recovery): `/nix/store/91jbl1irxi6qjx0252s00mlz8ass3yin-nixos-system-vlenovo-25.05.20250708.88983d4`
- Generation 57: `/nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4`
- Accelerated Flick wrapper: `/nix/store/k7rf872zph2192khxyrvx7fgzj40fl1r-flick-qt-egl-qml-system`
- Tested Flick executable: `/nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04`
- Kernel: `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36/bzImage`, identical to generation 56
- Initrd: `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36/initrd`, identical to generation 56
- Flake: `experiments/nixos-gpu-generation/flake.nix` with locked inputs. Base Flick NixOS configuration is `a3dcc0637b92bff7c30bc8914bda6ee1a3f50281`; graphics experiment is `20555d76e065e693a8f2b1f63b8f4fad80f427e1`.

## Builder fix and closure

MacBook Colima/Rosetta x86_64 Linux Nix 2.28.4 builder initially failed with `cannot set 32-bit personality: Invalid argument`. Two *identical store-path* GRUB 2.12 outputs and their requisites were imported from generation 56's tablet store to the builder, preserving the required 32-bit UEFI/GRUB settings. Full toplevel build then exited 0. The tablet accepted an export/import of only 16 changed closure paths (83 MiB on builder disk); the old and new complete closures each contain 1,319 paths, with 1,303 paths identical.

The new Flick systemd unit differs from generation 56's **only in ExecStart and FLICK_ROOT**. PAM, seatd, TTY, user, supplementary groups and service restart settings match.

Installed via `sudo nix-env -p /nix/var/nix/profiles/system --set <new-system>`, `<new-system>/bin/switch-to-configuration boot`, and `<new-system>/bin/switch-to-configuration switch`. Activation returned exit 0. GRUB menu contains explicit entries for generations 57 and 56. The root systemd 8-minute rollback timer was armed before live switching, and was subsequently stopped before the approved reboot.

## Post-reboot proof

- Boot ID: `c3892a29-7d59-4d69-9ab1-10cb0d99aa6b` (changed from `dabf2a44-c4c4-48ca-9ba8-bfcbd3e05374`)
- Booted/current NixOS profile both generation 57.
- Flick PID 899 on new binary; NRestarts 0. QML PID 1031.
- QML: **four** open `/dev/dri/renderD128` descriptors, **zero** llvmpipe workers.
- ELAN1001 booted in ACPI state **D0**, `hid-multitouch` registered and `/dev/input/by-path/first-touchscreen -> ../event5`. Flick PID 899 has `/dev/input/event5` open. Input event numbering is not stable across boots.
- Flick, SSH, NetworkManager and seatd active; Wi-Fi interface wlan0 up; systemd state running; no failed units.
- No temporary Flick drop-ins or running rollback timer after the reboot. Generation 56 remains selectable from GRUB.

**Physical visual correctness, actual finger taps, unlock, rotation and suspend/resume are not independently proven by SSH checks.** The ELAN1001 firmware/I2C initialization issue was previously intermittent despite successfully recovering with reboot; this boot succeeded.

## Manual recovery

At GRUB choose **NixOS - All configurations** → **Configuration 56**.

For a working SSH session, this changes the system profile back to generation 56 and activates it:

```sh
ssh -F ~/.ssh/vlenovo_config vlenovo
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 56
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

Do not run a garbage collection that deletes generation 56 before accepting the new display and touchscreen physically.
