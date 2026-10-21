# Lenovo Bay Trail graphics: direct KMS, Asterinas, and Rust driver-port feasibility

Snapshot: 2026-10-21. Project-local hardware claims are based on live gen57 checks and the retained `docs/graphics/GPU-BASELINE.md`, `docs/graphics/FLICK_GEN57_DEPLOYMENT_2026-10-21.md`, and the prior Rust thin-terminal report.

## Layer map for real hardware acceleration

```text
Rust Slint application (the proven version is Wayland/Winit 1.7.2)
     |  Wayland renderer            | native LinuxKMS           | LinuxKMS EGL + FemtoVG
     v                              v                           v
Flick Rust compositor        Slint DRM dumb buffers       Slint GBM + EGL/GLES
     |                              |                           |
  Smithay/libinput          libseat/libinput             libseat/libinput
     |                              |                           |
     +----------------------+-------+---------------------------+
                            |
                Linux DRM/KMS / i915 driver
                    Bay Trail / Valleyview
              8086:0f31 / PCI / DSI panel
                            |
          DSI-1 1920x1200 + backlight + touchscreen
```

**Different meanings of acceleration:** DRM dumb buffers + KMS already use the dedicated display scan-out engine, but Slint's `linuxkms-software` **draws its pixels on CPU**. Real GPU-accelerated GUI drawing needs a valid Intel Mesa Crocus OpenGL/EGL context (the `linuxkms-femtovg` variant); observing `/dev/dri/renderD128` and Mesa renderer not `llvmpipe` provides partial proof. Also verify actual GPU command submission, CPU use under scrolling, DSI page-flip consistency, and battery drain. VA-API H.264 uses a *different* decode path; it may help remote-video mode but is not an OpenGL substitute.

**Documented working present stack:** gen57 boots x86_64 Linux 6.12.36 through 32-bit UEFI GRUB, i915 DRM/KMS, Mesa Crocus, Flick native DRM on seatd, QML GLES lockscreen with four render-node FDs and zero llvmpipe threads. The ELAN1001 I2C driver bound on fresh boot, and Flick opened its `/dev/input/event5` at that boot. User confirmed unlocking and faster workspace. Never hardcode card1 or event5 across boots.

## Direct Slint KMS API reality

Slint LinuxKMS officially supports DRM dumb buffers/software, libinput, libseat, and EGL/GBM with GPU renderers. Its renderer selection includes `SLINT_BACKEND=linuxkms-software` and `linuxkms-femtovg`. The already-compiled app uses **Slint 1.7.2 `backend-winit-wayland`**, not direct KMS. It must be recompiled with `backend-linuxkms` + the appropriate native libs, potentially requiring a revised lockfile and Rust toolchain. Documented feature semantics changed in Slint 1.18, so do not indiscriminately paste 1.18 flags into the pinned 1.7.2 Cargo package.

Libseat must own the one DRM master. Flick should be stopped (not racing the KMS app). Select DRM connector by connected `DSI-1` and verify orientation; Slint `SLINT_KMS_ROTATION` only rotates the image, touchscreen libinput calibration is separate. Keep the ELAN kernel driver and /dev/input/by-path discovery, ACPI/BATC, backlight and Wi-Fi.

Source: https://docs.slint.dev/latest/docs/slint/guide/backends-and-renderers/backend_linuxkms/
Source: https://github.com/slint-ui/slint/blob/master/docs/development/window-backend-integration.md

## Asterinas 0.19.0: what DRM really provides

On 2026-10-13 Asterinas announced a DRM core, KMS/GEM dumb buffers, `/dev/dri`, and Xorg with **Mesa software OpenGL** in Asterinas NixOS. This is a kernel and userspace compatibility milestone, **not** a Bay Trail i915 hardware driver. Asterinas 0.19 also gained a device model, but the project does not claim this Lenovo's DSI panel, Wi-Fi firmware, I2C ELAN HID, sensors, power or mixed IA32-UEFI loader. Build its **own** NixOS VM image through `make nixos` and `make run_nixos`. No `nixos-rebuild --flake ...#asterinas` activation on physical tablet exists in this repo.

Source: https://asterinas.github.io/2026/10/13/announcing-asterinas-0.19.0.html
Source: https://github.com/asterinas/asterinas (v0.19.0 tag)

## Windows driver -> Linux -> Rust? Practical answer

A compiled Windows WDDM `.sys`/UMD DLL is **not** a Linux kernel DRM driver. WDDM uses `dxgkrnl`, proprietary Windows APIs, kernel display miniport DDIs and a corresponding userspace Direct3D UMD. Linux needs an i915-equivalent DRM/KMS device (mode objects, GEM buffers, atomic page flips, interrupts, power state, DSI panel sequencing) and typically Mesa interfaces for rendering. Even if you have legal access to **driver source code**, hardware register constants and algorithms might transfer but OS-bound entry points, memory handling, scheduling, IOCTLs and power management must be rewritten.

**Engineering sequence:** (1) document actual PCI ID, GPU gen, DSI panel paths, ACPI methods, driver trace and register documentation; (2) compare Linux i915 open source implementation with Windows INF/binaries *as behavioral references*, respecting licenses; (3) implement a tiny read-only PCI/DRM probe and QEMU test; (4) support firmware/probe, memory/interrupt/IOMMU/GEM handling; (5) display detection/DSI power + KMS dumb-buffer scanout; (6) power/suspend/brightness; (7) render-node acceleration/command submission and Mesa/OpenGL integration; (8) runtime stabilization, fuzzing and maintain across kernels; (9) port separate ELAN I2C touch and Wi-Fi drivers if replacing Linux.

**Order-of-magnitude estimates, not published schedules:** with one experienced Rust + graphics-kernel engineer, roughly **2–8 weeks** for a narrow probe and a toy KMS experiment using good public documentation; **6–18+ months** for a robust Bay Trail internal-DSI modesetting/power driver; **18–36+ months** for near-feature-complete accelerated GPU drawing and integration; another **6–18+ months** or more to make a new kernel's ACPI/I2C, Wi-Fi, battery, suspend, audio and full tablet hardware actually dependable. Without Intel's internal register/panel information, some milestones may be unachievable in a predictable timeframe. Legal clean-room reverse engineering and source license review are prerequisites, not shortcuts.

**Strong alternative:** use Linux's mature `i915` KMS in the new *Rust userspace*. The Linux Rust-for-Linux Nova GPU driver demonstrates that Rust DRM/GPU code is real but is built for modern NVIDIA GPUs with a firmware GSP; it does **not** add support for legacy Intel Bay Trail. Porting from Linux C i915 code to Rust may be more realistic than from a Windows driver binary, but still requires enormous effort and hardware validation.

Sources:
- https://learn.microsoft.com/en-us/windows-hardware/drivers/display/windows-vista-and-later-display-driver-model-architecture
- https://learn.microsoft.com/en-us/windows-hardware/drivers/display/migrating-to-the-windows-vista-and-later-display-driver-model
- https://docs.kernel.org/gpu/drm-kms.html
- https://dri.freedesktop.org/docs/drm/gpu/i915.html
- https://rust-for-linux.com/nova-gpu-driver

## Memory experiments and measurable targets

Gen57 baseline after fresh boot/lockscreen: `free -m` gave 1,866 MiB total and 1,327 MiB available at first check; after workspace unlock a later reading showed roughly 1,380 MiB available. The exact runtime varies, so compare *identical* unlocked/locked states. Historical Rust Slint Wayland dashboard: around **42.5 MiB RSS** and about **9–10% CPU** (three-second telemetry updates). Historical optimized Flick + QML soak: approximately 28.6% combined one-core CPU versus approximately 125.7% baseline. RSS cannot simply be summed because shared code/data mappings are duplicated; compare PSS and private dirty memory.

Recommended benchmarks: 5-minute warmed-up idle, 60 taps, continuous scroll, font repaint, video decode if needed, 1-hour battery idle. Log each `/proc/*/smaps_rollup` PSS and total `MemAvailable`, GPU renderer name, /dev/dri FDs, `i915` reset logs, DSI resolution, ELAN tap response, wake from suspend, Wi-Fi connectivity. The highest-value savings probably come from removing unused compositor/Qt/Wayland layers and changing full-screen repaint habits, not from rewriting the already-working kernel driver. Direct software rendering can *increase* CPU use during animations or large redraws.

## Mixed UEFI and MacBook build / tablet transfer

The firmware's `/sys/firmware/efi/fw_platform_size = 32`; processor and OS `uname -m = x86_64`. NixOS option `boot.loader.grub.forcei686 = true` builds an IA32 EFI GRUB that can boot the 64-bit kernel. Do not reinterpret the Rosetta `cannot set 32-bit personality` build error as meaning the tablet needs an i686 operating system.

The proven MacBook workflow is **Colima VZ + Rosetta x86_64 Linux + NixOS Nix**, with pinned exact flake inputs; build x86_64-Linux system toplevel *inside* that container; for Rosetta Nix builds use container-scoped `--option sandbox false --option filter-syscalls false`. If GRUB's 32-bit builder fails, import the **identical** prebuilt GRUB Nix-store paths from tablet generation 56/57, not alternative firmware binaries. Transfer the full built Nix store closure (including runtime references) over authenticated SSH `nix-store --export | nix-store --import`; register via `nix-env -p /nix/var/nix/profiles/system --set`; update GRUB and activate via `switch-to-configuration boot/switch` after temporary rollback timer. The full gen57 image was archived separately on Mac in `.local/archives`.

Sources: https://nixos.org/manual/nixos/stable/ ; https://nixos.org/manual/nixos/unstable/options#opt-boot.loader.grub.forcei686
