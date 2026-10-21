# Low-RAM Rust Slint while retaining Intel GPU acceleration

Data taken **read-only from real NixOS generation 58** on 2026-10-21. The experimental branch does not change the booted system by itself.

## Starting numbers (warm, responsive touch confirmed)

- Intel Atom Z3745 tablet, 1,911,176 KiB (~1,866 MiB) RAM.
- `MemAvailable` ~1,524,604 KiB (~1,489 MiB), Linux accounted used ~380–390 MiB; swap used **0**.
- Slint Direct-KMS process: `Rss: 80,640 KiB`, `Pss: 76,231 KiB`, `Pss_Anon: 25,400 KiB`, `Pss_File: 50,831 KiB`, `Private_Dirty: 25,400 KiB`.
- i915 `/proc/$PID/fdinfo/5`: ~39,444 KiB system graphics allocations. **GPU buffer allocation is separate from process PSS**, so avoid adding these numbers as an exact system-wide footprint.
- Other top process **RSS** examples: nix-daemon ~31,292 KiB; NetworkManager ~21,964 KiB; systemd-journal ~15,384 KiB; systemd ~14,552 KiB; wpa_supplicant ~11,580 KiB; bluetoothd ~5,624 KiB. RSS shares mapped memory; summation overcounts.
- Current Slint timer refreshes status from local files every **3 seconds**, but tapped actions update the UI immediately. Idle CPU on a warm run ~0.5–1.4% of one core.
- Generation 57 with Flick at the same approximate boot period previously reported ~1,307 MiB MemAvailable; generation 58 around 1,480 MiB. **Not a controlled A/B comparison** of identical workload and cached pages.

## Why rewriting the kernel is the wrong memory lever today

Asterinas NixOS's release examples run in 8 GiB VM and its only DRM driver is `simpledrm` with software-drawn buffers. It does not expose the i915 device required by the present Mesa Crocus OpenGL Slint path. Replacing the Linux kernel removes mature Wi-Fi/touch/power drivers and sacrifices acceleration; it does not prove a RAM win.

## Practical optimization experiments, cheapest first

1. **Compile a FemtoVG-only Rust app:** this experiment's `experiments/nextgen-images/native-kms/Cargo.toml` may omit the redundant `renderer-software` feature while keeping `compat-1-2`, `std`, `backend-linuxkms`, `renderer-femtovg`. Pin the same Slint 1.7.2. This can reduce the binary and loaded file pages without changing GL execution. It needs an actual native Nix build and an A/B same-screen process PSS test, not an assumed memory saving.
2. **Event-driven status instead of 3-second polling:** user actions should still update immediately. Periodically updating Wi-Fi/battery/uptime every 10–15 sec might cut idle wakeups, but may not save RAM; track latency, CPU and battery drain. Slint `Timer` retains scene state. Do not rate-limit the touch callbacks.
3. **Reduce outstanding full-screen GPU buffers only if measurement proves excessive:** 1920×1200×4 bytes = 9,216,000 bytes (~8.79 MiB) per RGBA/XRGB buffer. An additional buffer may cost ~9 MiB, but it also prevents tearing/stalls. Upstream `gbmdisplay.rs` and i915 GEM should be studied before experimenting; keep 60 Hz and page-flip reliability.
4. **Optional service audit only:** `nix-daemon` can be socket activated; Bluetooth, modem, SSH, NetworkManager, journald, timesync, input and seatd have very different criticality. Never disable essential power/Wi-Fi/SSH/udev recovery just for a synthetic benchmark. Bluetooth should remain while tablet usage requirements are unknown.
5. **Slint scene memory:** inspect large fonts, textures, and layouts; avoid giant cached images, pre-rendered screenshot layers and unnecessary clones. Use GPU-only renderer from #1 and profile concrete component sizes.
6. **NixOS closure reduction vs runtime RAM:** 1,222 store paths vs 1,319 does not directly imply 97 fewer resident libraries. Cached Nix-store pages remain reclaimable; measure PSS and `MemAvailable`.

## Controlled benchmark acceptance

Record 5-min and 1-hour warm idle under the *same displayed scene*, Wi-Fi association, brightness, backlight resolution, power adapter/battery, thermal and process mix. Sample `MemAvailable`, whole-system used, `/proc/$PID/smaps_rollup`, `/proc/$PID/fdinfo/*` for i915 allocations, `ps` CPU over same time window, and battery %/time. Tap status/help/network at least 30 times and ensure counter/actions are correct; check rotation, drag, suspend/resume, and zero GPU hangs.

Use `/proc/$PID/smaps_rollup` proportional/private dirty rather than summing `ps RSS`. A runtime reduction of a few MiB without better battery/latency is not worth losing the already confirmed touch responsiveness. **Do not overwrite the golden generation 58 for unmeasured tweaks.**
