# Asterinas + DRM: proposed Lenovo OS generation 59 (VM-first)

**Experiment branch only. No physical NixOS generation 59 is installed.**
Baseline **NixOS 58** is on its own golden GitHub branch and the tablet keeps booting it.

## Source and reproducibility

- Project: https://github.com/asterinas/asterinas
- Pinned source: **v0.19.0**, Git commit `c4b7ed575b7b32773475b194d2ad41fb6d03765b` (2026-10-13 release).
- Official release ISO: https://github.com/asterinas/asterinas/releases/download/v0.19.0/asterinas-nixos-0.19.0-x86_64.iso
- GitHub release reports **1,442,840,576 bytes** and SHA256 **7df9fafed4fe886e44bda501834937d893e12a05af911fabeb068c34379fb86e**.
- The official Asterinas `distro/etc_nixos` tree is the basis of the upstream NixOS port; its `modules/core.nix` bypasses the normal NixOS Linux-kernel builder, generates its own initrd and `kernel-params`, and places the custom OSDK kernel at `$out/kernel`.
- **Live-ISO caveat proven experimentally:** the official ISO installer *first boots Linux 6.18.39*. Its `/dev/dri/card0` and `Virtual-1` connector are from Linux, not Asterinas. The installed Asterinas kernel has **now booted and been verified directly** on QCOW2, including `/dev/dri/card0`, both at 4096 MiB and 1792 MiB QEMU RAM. The booted kernel is **Asterinas 5.13.0**, not Linux. `EXPERIMENT_STATUS.md` records installation, initial MSI-X panic, corrected VirtIO device settings, successful kernel/DRM/console checks and memory evidence.
- Local VM launch script: `scripts/boot-official-iso-macos.sh`. Runs QEMU x86_64 **TCG** on the Mac, never on the Lenovo. The shipped ISO is unmodified and mounted read-only. Check the SHA **before** using it.

## Hardware-blocker table (inspected upstream v0.19.0 Rust sources)

| Need | Linux gen58 working | Asterinas v0.19.0 status | Consequence |
|---|---|---|---|
| x86_64 kernel | Linux 6.12.36 | Asterinas x86_64 supported | A CPU match alone does not make a tablet port |
| Intel i915 DSI-1 | i915 on 8086:0f31, 1920×1200 panel | New `aster-drm` core + `simpledrm` **virtual connector**, no i915/Valleyview/DSI device driver found in tagged tree | **Hard boot blocker for the real screen** |
| Accelerated GL | Mesa Crocus GBM/EGL, Slint FemtoVG | `simpledrm` reports `DrmFeatures::empty()` (no RENDER DRM minor) and implements CPU dumb-buffer modesetting | **GPU acceleration not provided** even if Xorg/Mesa software rendering works |
| Finger touch | ELAN1001 I2C HID ACPI with `hid-multitouch` | No demonstrated ELAN1001 or equivalent ACPI/I2C-HID touch driver | **Cannot claim touch works** |
| Wi-Fi / SSH | Tablet's Linux stack tested | Asterinas supports VM VirtIO networking; physical Wi-Fi driver not validated | Remote management may disappear |
| 32-bit EFI + 64-bit CPU | IA32 GRUB `forcei686` boots x86_64 Linux | Official NixOS port uses EFI/handover64 protocol and does not specify an IA32 GRUB build for this machine | Boot handoff unresolved |
| RAM | 1,866 MiB physical, gen58 PSS ~75 MiB | **Installed Asterinas NixOS boots at 1792 MiB QEMU RAM**; 157 MiB used at minimal root shell | Minimal VM fits physical budget; full Slint + driver workload is untested |

The driver gap is **source-derived**, not a guess from screenshots: `kernel/comps/simpledrm/src/lib.rs` sets `DrmConnectorType::Virtual`, registers a framebuffer and `DrmFeatures::empty()`. `kernel/comps/drm/src/lib.rs` only registers a render minor for `DrmFeatures::RENDER` devices. Thus Slint's `linuxkms-femtovg` path (which needs EGL/GBM on a GPU device) does not work on Asterinas simpledrm merely because `/dev/dri/card0` exists.

Tag sources:
- https://github.com/asterinas/asterinas/blob/v0.19.0/kernel/comps/simpledrm/src/lib.rs
- https://github.com/asterinas/asterinas/blob/v0.19.0/kernel/comps/drm/src/lib.rs
- https://github.com/asterinas/asterinas/blob/v0.19.0/distro/etc_nixos/modules/core.nix
- https://asterinas.github.io/2026/10/13/announcing-asterinas-0.19.0.html
- https://asterinas.github.io/book/distro/
- https://asterinas.github.io/book/kernel/nix-development.html

## Actual near-term prototype stages

1. **Completed: official ISO installed and Asterinas kernel booted in QEMU** using the 12 GiB QCOW2 file, TCG, UEFI GRUB and the MSI-X-compatible modern VirtIO disk configuration. Verified guest `uname -a`, `/dev/dri/card0`, virtual input events, and memory at 1792 MiB. **Not yet completed:** a real DRM dumb-buffer modeset, running Slint software KMS, or any Intel GPU acceleration.
2. Use Asterinas's upstream `make kernel`, `make nixos`, `make run_nixos` on a Linux x86_64 machine **with KVM, enough RAM/disk and privileged loop devices**. Our Colima/Rosetta x86_64 container has **no /dev/kvm** and approximately 5 GiB VM memory; upstream `make nixos` needs loop privileges and standard VM examples use 8 GiB. When using Nix developer shell, `make iso && make run_iso` is the supported alternate route, subject to resource limits.
3. **Next:** prove an **Asterinas + Slint LinuxKMS software** fullscreen UI in QEMU's virtual/simpledrm framebuffer. Use `linuxkms-software`, check the DRM ioctls, udev/input and build/deploy the minimal guest UI. This tests userspace compatibility but *does not* meet the high-GPU-performance requirement.
4. For tablet hardware: port ACPI enumeration, I2C/HID ELAN, Intel Bay Trail i915/DSI KMS+GEM+render, Wi-Fi/firmware, brightness/power/suspend; port/test a 32-bit UEFI loader. Demonstrate native OpenGL/EGL Crocus on the Asterinas GPU device before attempting `linuxkms-femtovg`.
5. Only when all physical tests pass, create a **boot-only selectable** experimental generation 59 on the Lenovo with watchdog rollback to 58 and 57, keeping kernel/initrd/EFI rescue paths. Do not alter running 58 while researching.

## RAM alternative without changing the kernel

See `RAM_OPTIMIZATION.md` for direct measurements and low-risk candidate changes to Slint code/feature flags, unused services and DMA buffer allocation. The working Slint + Linux system is already substantially smaller than the prior Flick desktop; skipping the compositor saved more predictable resources than replacing a mature GPU kernel driver.

**Never present the QEMU ISO as a tablet-ready image.** The golden physical system and backup are preserved separately.
