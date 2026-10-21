# Asterinas DRM generation-59 virtual prototype: installed, booted, verified

**2026-10-21 — real Asterinas v0.19.0 kernel verified in QEMU; tablet NixOS generation 58 remains unchanged.** The tag is `v0.19.0` / upstream commit `c4b7ed575b7b32773475b194d2ad41fb6d03765b`. This is a VM/prototype branch, NOT an activated NixOS profile generation 59.

## Proven artifacts and installation

- Official ISO SHA256 `7df9fafed4fe886e44bda501834937d893e12a05af911fabeb068c34379fb86e`, length **1,442,840,576** bytes, verified on Mac. Its live installer runs **Linux 6.18.39**, *not* the Asterinas kernel; the installed guest is different.
- MacBook QEMU **11.1.2 x86_64 TCG** and x86_64 OVMF firmware. The MacBook cannot use KVM hardware acceleration for an x86 guest.
- Installed onto a **12GiB sparse QCOW2** guest disk `.local/archives/asterinas-gen59-test-disk.qcow2` (about **2.1 GiB physically allocated** immediately after install). The installer saw exactly one writable 12 GiB VirtIO disk `/dev/vda`, no tablet or Mac physical disks.
- Installer command executed from guest root shell: `aster-nixos-install --config configuration.nix --disk /dev/vda --force-format-disk`. Installation completed with the on-screen confirmation **“Asterinas NixOS has been installed successfully!”**, including GRUB EFI install.
- `scripts/boot-official-iso-macos.sh` contains `check|boot|install|boot-installed` commands and keeps all writes inside VM files; no remote tablet image/boot changes.
- **Exact reusable installed-guest disk:** Mac local `.local/archives/asterinas-gen59-test-disk.qcow2`, 12 GiB virtual / 2.13 GiB allocated. After clean guest sync and stopping QEMU, `qemu-img check` returned **No errors were found on the image**. QCOW2 SHA-256: `67e2072cad94018942a264d06ca19ba89ea2d2429854f7225be2d617151043b8`.
- **Compressed VM checkpoint:** Mac local `.local/archives/asterinas-gen59-0.19.0-1792MiB-verified.qcow2.zst`, **445 MiB**, `zstd -t` passed. SHA-256 `8e30d359124253e03f7764047371110637d8b7538cbe784e87da8119359a70ca`. This binary is deliberately **not committed to GitHub**, which stores rebuild instructions, evidence, pinned release checksum and source.
- Restoring the exact image on the Mac: from the gen59 worktree, set `ARCHIVE="$HOME/Documents/Work/vlenovo-nixos-tablet/.local/archives"`; run `zstd -dc "$ARCHIVE/asterinas-gen59-0.19.0-1792MiB-verified.qcow2.zst" > "$ARCHIVE/asterinas-gen59-test-disk.qcow2"`; then run `ASTERINAS_VM_RAM_MB=1792 ASTERINAS_OVMF_VARS="$ARCHIVE/fresh-asterinas-uefi.fd" ./experiments/gen59-asterinas/scripts/boot-official-iso-macos.sh boot-installed`. The launcher auto-creates a fresh UEFI variables file, uses a modern MSI-X capable VirtIO disk, and serves VNC on localhost 5927. Do not overwrite the working disk while a VM is running.

## Real Rust kernel boot and debugging

1. First boot with the original installer-provided UEFI variables fell through to PXE. A fresh guest OVMF variables file resolved that boot-entry issue.
2. The first GRUB-to-Asterinas handoff **reached the true Asterinas EFI stub** but panicked at `kernel/core/comps/virtio/src/transport/pci/device.rs:321`: `called Option::unwrap() on a None value`. Upstream source at v0.19.0 confirms this line calls `acquire_msix_capability().unwrap().unwrap()` and has the adjacent TODO **“Support interrupt without MSI-X.”**
3. Switched installed-disk QEMU arguments from implicit `-drive ... if=virtio` to explicit `-drive if=none,id=u0,format=qcow2,file=...` and `-device virtio-blk-pci,drive=u0,disable-legacy=on,disable-modern=off,vectors=4`; disabled the optional VirtIO networking device while isolating PCI probe. The Asterinas kernel now boots rather than panicking.
4. An OVMF session with stale boot entries required the EFI shell command `fs0:\\efi\\boot\\bootx64.efi` to launch GRUB. A fresh OVMF vars template with the updated PCI layout instead booted the disk **automatically** and is the best reproducibility path.
5. Successful serial trace: EFI stub loaded Asterinas, initialized OSTD and components, unpacked initramfs and logged **`[kernel] running /init as the init process`**. The guest framebuffer displayed the **Asterinas NixOS 26.05pre-git (x86_64) tty1 root prompt**.
6. Guest `uname -a`: `Linux asterinas 5.13.0 #1 SMP Mon Oct 12 21:30:40 UTC 2026 x86_64 GNU/Linux`. This is Asterinas's **Linux-compatible uname**, not the Linux 6.18.39 installer.
7. The **actual Asterinas DRM device** `/dev/dri/card0` exists, a character device (root-owned, major **226**, minor **0**). No `/dev/dri/renderD128` was present. `/sys/class/drm` did not exist in the guest. These facts match the upstream `simpledrm` Rust framework: basic boot-framebuffer DRM, **not Intel i915 GPU acceleration**.
8. At 4096MiB QEMU RAM: guest `free -m` showed about **226 MiB used** of 4,070 MiB guest-visible, no swap, and 3,843 MiB available. This VM does not run the Lenovo Slint dashboard, Wi-Fi, Bluetooth or tablet sensors.
9. Restarted installed guest with **1792 MiB QEMU RAM**, below the Lenovo's physical 1866 MiB. It **automatically booted Asterinas and NixOS userspace**, root prompt responsive; `free -m` reported **1766 MiB guest-visible, 157 MiB used, 1608 MiB available, swap 0**. `/dev/dri/card0` and `/dev/input/event0,event1` present. This proves the **minimal VM** boots within tablet-class RAM, not that the real tablet drivers/UI work.
10. Optional network test: attaching modern `virtio-net-pci` with `disable-legacy=on,disable-modern=off,vectors=4` *also booted the Asterinas kernel* without the initial MSI-X panic. QEMU host-forwarding listened at loopback TCP 22259; however, SSH into the guest **timed out during banner exchange**, so working guest TCP networking and management **are not confirmed**. Default remains the no-NIC known-working mode until investigated.

## Evidence

- `evidence/asterinas-4096m-drmshell.png`: installed Asterinas guest commands `uname -a`, `/dev/dri/card0`, virtual memory.
- `evidence/asterinas-1792m-drmshell.png`: same installed guest with <1866MiB RAM and `free -m`, DRM/input.
- `evidence/asterinas-1792m-boot-serial.txt`: Asterinas EFI stub and initramfs boot evidence.
- `evidence/asterinas-virtio-net-experiment.png`: guest virtual NIC experiment. **Not proof of functioning guest network**.
- `scripts/vnc-capture.py`: loopback-only RFB capture/send-keys helper, so evidence comes from QEMU's framebuffer. Local root password/SSH are **not** provisioned for the VM.

## Remaining blockers to tablet gen59

- No Intel Bay Trail i915/DSI-1 KMS GEM/rendersupport in upstream Asterinas v0.19.0; `simpledrm` only. Mesa Crocus/FemtoVG EGL/GBM hardware acceleration cannot be promised. Rust DRM core **does not imply a physical Intel GPU driver**.
- No proven ELAN1001 ACPI + I²C HID + `hid-multitouch` path; actual physical touchscreen must work before replacing Linux.
- No proven tablet Wi-Fi, audio, brightness, power, suspend/resume, orientation, IA32 EFI loader compatible with its BIOS. Current VM boot uses an x86_64 UEFI OVMF guest; Lenovo requires IA32 GRUB booting x86_64 CPU code.
- No full GUI or Slint LinuxKMS software renderer test yet; DRM character-device registration is narrower than working modeset/scanout. **SSH via optional modern VirtIO networking is also not yet functional** in the tested configuration.
- Asterinas kernel `poweroff` in QEMU printed **“Failed to power off the system / Halting the machine”** and the emulator needed explicit termination. This is a VM lifecycle limitation relevant to unattended recovery. No automatic rollback should rely solely on guest poweroff.
- The 157 MiB and 226 MiB guest-used figures **cannot be compared as equivalent** to the real gen58 system's ~376 MiB used, because the services/device mix and image workloads differ.

## Proven tablet safety invariant

Tablet `/run/current-system` and `/nix/var/nix/profiles/system` remain gen58:
`/nix/store/6mx70c7wm276rax10m7hcpzdsli2ndzb-nixos-system-vlenovo-25.05.20250708.88983d4`.
GUI `lenovo-slint-dashboard.service`, NetworkManager, seatd and SSH active. **0 restarts** after earlier bounded low-RAM trial. Physical touchscreen confirmation by the tablet owner retained in golden branch `lenovo-gen58-slint-kms-gpu-touch-golden-2026-10-21`.

**Do not install as physical generation 59 yet.** This branch contains a reproducible working Asterinas NixOS **virtual** prototype; the next meaningful driver work is Intel/ELAN hardware bringup, not blindly swapping kernels.
