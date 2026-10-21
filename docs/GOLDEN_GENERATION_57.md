# Lenovo Miix 2 10 — Golden NixOS generation 57 (2026-10-21)

**Verified stable checkpoint: do not overwrite.** Branch `lenovo-gen57-touch-gpu-golden-2026-10-21`.

## Physical acceptance

The tablet owner confirmed that the accelerated interface is notably more responsive, the screen can be unlocked, and the workspace loads faster. Earlier physical input testing confirmed Slint touch-action callbacks. Following the generation-57 reboot, ELAN1001 was re-enumerated with ACPI power D0 and Flick held the corresponding evdev touchscreen descriptor open.

The working stack: **x86_64 NixOS 25.05, Linux 6.12.36, native Flick DRM/KMS compositor, Intel i915 Bay Trail / Mesa Crocus, ELAN1001 I2C HID touchscreen, Wi-Fi, SSH, seatd**. QML lock screen used four `/dev/dri/renderD128` descriptors and zero llvmpipe workers; Flick had zero restarts. Those descriptors confirm GPU use, not that every UI operation is hardware rendered.

On the physical device `cat /sys/firmware/efi/fw_platform_size` returned **32**, while `uname -m` returned **x86_64**: 32-bit EFI firmware boots the 64-bit Linux system using `boot.loader.grub.forcei686`. Do **not** change bootloader width to fix a cross-builder error.

## Exactly installed paths

- Generation: **57**
- System: `/nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4`
- Old recovery generation 56: `/nix/store/91jbl1irxi6qjx0252s00mlz8ass3yin-nixos-system-vlenovo-25.05.20250708.88983d4`
- Flick package: `/nix/store/k7rf872zph2192khxyrvx7fgzj40fl1r-flick-qt-egl-qml-system`
- Kernel: `/nix/store/mifh5p043cma8pbywl2lvlkp1z1bd8i2-linux-6.12.36/bzImage`
- Initrd: `/nix/store/8hla2afa7n9vgs76l3558wy7gywxv8gv-initrd-linux-6.12.36/initrd`
- Boot ID after verified reboot: `c3892a29-7d59-4d69-9ab1-10cb0d99aa6b`

## Exact image recovery

`experiments/nixos-gpu-generation/flake.nix` and its `flake.lock` in this branch describe the **boot-verified generation** with immutable pinned integration and GPU package revisions. `docs/graphics/FLICK_GEN57_DEPLOYMENT_2026-10-21.md` records the full installation, including the preserved IA32 GRUB outputs and 16-path closure delta. `mvp/native/` holds the verified Rust + Slint Wayland dashboard and its Cargo lockfile.

**Complete Nix-store image archived on the authorized MacBook (local backup, not committed to public GitHub):**

`~/Documents/Work/vlenovo-nixos-tablet/.local/archives/lenovo-nixos-gen57-store-closure.nar.zst`

- Full 1,319-path store closure (not a raw disk image; excludes personal files, partition table, firmware variables, writable OS state, and EFI partition bytes)
- Uncompressed Nix store closure approximately **5.01 GiB**
- Compressed Nix archive approximately **2.03 GiB**
- SHA-256: `092786817aa043cd61d3380c0579fbe2ad04e55dbfe7249a87b843083a5724a9`
- To verify on Mac: `shasum -a 256 /path/to/lenovo-nixos-gen57-store-closure.nar.zst` and `zstd -t /path/to/lenovo-nixos-gen57-store-closure.nar.zst`
- On a trusted Linux target running Nix, after copying the archive there: `zstd -dc lenovo-nixos-gen57-store-closure.nar.zst | nix-store --import`. Verify `nix-store --verify-path /nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4`.
- To activate **only after hardware prerequisites and rollback**: `sudo nix-env -p /nix/var/nix/profiles/system --set /nix/store/14drwqmla8jzr9iinsj4an1shb704xd2-nixos-system-vlenovo-25.05.20250708.88983d4`; `sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot` or `switch`. This archive is compatible with the current tablet, not a generalized installer image.
- The binary archive is stored locally because the GitHub repository is public and source-control branches are not suitable for multi-GiB Nix store exports. To rebuild, follow `experiments/nixos-gpu-generation/flake.nix` in the same isolated Colima/Rosetta Linux builder and reuse the previously verified IA32 GRUB store outputs if Rosetta fails to create them.

## Recovery

At GRUB: `NixOS - All configurations → Configuration 56`. Or via SSH:
```sh
sudo nix-env -p /nix/var/nix/profiles/system --switch-generation 56
sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
```

**Retention:** do not run Nix garbage collection that removes generation 56. Do not promote Asterinas or experimental LinuxKMS changes into this golden branch. Touch event nodes can change across boots; discover touchscreen by udev/by-path, not hardcoded `event4` or `event5`.
