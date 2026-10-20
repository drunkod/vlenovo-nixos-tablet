# Lenovo native Rust + Slint MVP (stage 2)

A **read-only, native Rust + Slint 1.7.2** Wayland client for the Lenovo Miix 2 10. Isolated from NixOS configuration and the Flick compositor. This follows the successful touch-event experiment in `../slint/`.

## Prototype capabilities

- Live metrics every three seconds from `/sys/class/power_supply/BATC`, `/proc/meminfo`, `/proc/uptime` and `/sys/class/net/wlan0/operstate`.
- Three large touch actions: Status, Assist (help), and Network. In-app text input with Run button if a keyboard is available.
- Rust handlers accept an exact read-only allowlist: `status`, `memory`, `battery`, `network`/`wifi`, `uptime`, `help`/`assist`. Unknown commands are rejected, never passed to a shell.
- UI response updates directly in Slint from Rust. Real inputs are logged to `~/lenovo-mvp/native-events.tsv` with Unix timestamps and sanitized command labels.
- No on-device LLM, AI service, model download, root privileges, sensor reset, brightness change or configuration mutations.

## Reproduce from the MacBook

```bash
cd ~/Documents/Work/vlenovo-nixos-tablet/mvp/native
./run-on-tablet.sh sync
./run-on-tablet.sh build   # Compiles on x86_64 tablet, max two Cargo jobs
./run-on-tablet.sh start
./run-on-tablet.sh status
ssh -F ~/.ssh/vlenovo_config vlenovo 'tail -20 ~/lenovo-mvp/native-events.tsv'
./run-on-tablet.sh stop
```

Build relies on the NixOS tablet's Nix registry, the cached Rust 1.98 toolchain, and network access to crates.io when offline crates are missing. The ARM64 MacBook is used to write and synchronize the source but does not generate an x86_64 Linux executable in this setup. Dependencies are locked in `Cargo.lock`.

Run stage-one backup independently from `../slint/run-on-tablet.sh start`. Do not run both UIs simultaneously for final performance tests. The native binary is in `~/lenovo-mvp/native/target/debug/lenovo-native-mvp` on the tablet. The launcher uses its existing `/run/user/1001/wayland-1` socket.

## Acceptance gates

1. Native build completes, backend connects to Flick Wayland without crashing; no NixOS `test`, `switch` or reboot.
2. Battery reading matches `BATC`, memory matches `/proc/meminfo`, Wi-Fi link matches `operstate`, uptime increases automatically.
3. Physical finger taps and Run button immediately change the visible response; confirmed logged events match interactions.
4. Idle CPU/memory measured with `top` after 30 seconds. Check original Flick and Qt lockscreen as independent CPU consumers.
5. Stop native app; verify Flick, SSH and Wi-Fi remain healthy; restart the stage-one Slint UI if desired.

**Caution:** An intermittent ELAN1001 I²C initialization timeout was observed and recovered with a controlled reboot on October 20; see `../../docs/TOUCHSCREEN_RECOVERY_2026-10-20.md`. Do not mistake missing kernel input for a frontend bug.

## Verified deployment, 2026-10-20

- Cargo build on the tablet completed successfully after resolving four Slint colour literals that Rust's macro tokenizer mistook for numeric tokens. First-time dependencies took about 17 minutes with two jobs; the cached-source rebuild took **28.35 seconds**.
- Native binary: `/home/alex/lenovo-mvp/native/target/debug/lenovo-native-mvp`, about **21 MB**.
- The first native smoke test found a dynamically loaded Fontconfig library missing. Runtime launcher now supplies `fontconfig-2.16.0`, Freetype, Wayland and xkbcommon library paths from the tablet's Nix store plus `FONTCONFIG_FILE=/etc/fonts/fonts.conf`. With those set, a controlled eight-second smoke test exited with `124` (expected `timeout`) and **no errors in the log**.
- The earlier Slint viewer was stopped and the native app successfully started as regular user `alex`, **PID 5302**. It was still alive after approximately one minute, with an empty error log and no native action events yet.
- Measured native RSS around **43,560 KiB (42.5 MiB)** after startup, versus approximately 79,760 KiB (77.9 MiB) for the original Slint viewer. RSS is a per-process resident set including shared mappings, not incremental system RAM.
- Three-second `top` sample: native **8.6%** of one core while live telemetry updates, Flick **88.7%**, QML lockscreen **32.8%**. An earlier sample showed 0.0% native CPU. These are snapshots, not performance distributions.
- The tablet's ELAN1001 input remains `/dev/input/event4` with ACPI power `D0`; Flick, SSH, NetworkManager and seatd active; zero failed units. Current and booted NixOS generation unchanged.
- Separate native Rust read-only command handler compiled/tested directly: `status`, `battery`, `memory`, `network`, `uptime`, `help` returned current values; arbitrary `rm -rf /` was safely rejected.
- **Physical touchscreen/tap response on the new native UI was confirmed by the user** after deployment. The live `~/lenovo-mvp/native-events.tsv` recorded six additional native card/command callbacks (status, help and network) by 2026-10-20. The earlier viewer's separate ten-tap experiment is also documented in `../slint/README.md`.
- Future priorities: validate touch and text input, implement a safe accessible OSK if the Flick keyboard is incomplete, benchmark idle and interactions after full cleanup, and instrument Flick's unconditional redraw pathways on an isolated branch.

No different system image was built, no bootloader or NixOS service was modified, and there were no forced kernel/GPIO changes during this stage.
