# Wild third design: Linux i915 + one Rust AI-terminal process

Research blueprint only — **not a buildable or bootable NixOS generation** yet.

## Intent

Keep Linux 6.12.36 i915/ACPI/I2C/HID and IA32 GRUB for the physical DSI panel and ELAN touchscreen, but eliminate a general-purpose desktop, X11, Wayland, QML and browser. A single foreground Rust binary would manage libseat/libinput, Slint DRM scan-out, a minimal status/offline UI, a command channel, battery readings, and network reconnect. A more powerful Mac/phone supplies semantic scene updates and AI. Even this design needs local scan-out; remote agents cannot draw pixels on an unpowered DSI panel.

Phase 0: measure the `slint-kms` and `slint-kms-gpu` NixOS variants in this folder first. Phase 1: isolate a minimal set of Linux userspace services and build a reproducible NixOS activation. Phase 2: move the Rust app and firmware into a custom initrd/early userspace, with startup state machine and asynchronous IPC. Phase 3: consider replacing systemd only when independent watchdog, Wi-Fi, time sync, secure SSH recovery, OTA updater and persisted logs exist.

## Unique experimental bits

A bounded semantic scene protocol (typed JSON/CBOR with revision, max lengths, acknowledged paint), offline cached terminal UI, touch semantic IDs, and remote Mac inference. For heavy media, request a streamed compressed video region that uses Intel i965 VA-API H.264 decode while UI chrome remains Slint GPU/CPU drawn. A Mac/phone can provide voice, but agent commands must never be executable arbitrary shell on the tablet.

The most radical version uses a custom initramfs for Wi-Fi firmware+DRM+Slint and runs as a PID 1 state machine. That is *not* NixOS's standard full userspace image and must be proven first in QEMU/USB boot. Without a proven recovery and input/display path the design is too risky for the tablet's permanent boot.

## Fail and recovery gates

- Guarantee never to overwrite generation 57's `/boot/grub`, EFI variables, or root filesystem while testing.
- Verify IA32 GRUB handoff to x86_64 kernel unchanged; no unsupported i915 firmware paths.
- If rust UI panics: visible fallback status, safe restart, verified SSH access, and automatic GRUB boot restoration after failed self-test.
- Prove battery/panel/backlight, suspend and a physical tap in the same 1920x1200 DSI mode.
- Compare PSS, MemAvailable, CPU, wake latency and battery vs direct LinuxKMS; don't infer less RAM merely because one process is fewer than three.
