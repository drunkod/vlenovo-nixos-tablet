# GPU-only Slint memory experiment — isolated from proven gen58

Experimental branch `lenovo-gen58-gpu-lowram-experiment`, sourced from user-touch-verified NixOS gen58 golden commit `8a422fd`.

## Minimal changes

- `native-kms/Cargo.toml`: drop the `renderer-software` feature from the direct KMS GPU app. Continue to enable Slint `backend-linuxkms` + `compat-1-2`, `std` and explicit `gpu = ["slint/renderer-femtovg"]`. The current installed service selects `linuxkms-femtovg` with Mesa Crocus, so software fallback is redundant **under the already-verified hardware**.
- `native-kms/src/main.rs`: change periodic read-only battery/uptime/RAM/network refresh from 3 seconds to 12 seconds. Each UI card `TouchArea.clicked` callback still calls `refresh` synchronously; no delayed tap response is expected, but must be tested on-device.

## Hypothesis and safety

Reducing compiled renderers may shrink executable and mapped file pages, but PSS/file caches are only partly unreclaimable; **no RAM saving is asserted before A/B measurement**. Longer polling reduces idle wakeups, potentially battery usage, but does not itself reclaim large memory. Keep the same Slint version 1.7.2, DRM/KMS/GBM/EGL driver, 32-bit UEFI boot mechanism, ELAN driver and all recovery entries.

## Builder experiment

The MacBook's Colima/Rosetta x86_64 Linux Nix builder can build:
```sh
docker --context colima-vlenovo-flick-build cp experiments/nextgen-images/. vlenovo-flick-nixbuild:/nextgen-lowram
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
    --option sandbox false --option filter-syscalls false --option max-jobs 2 --option cores 2 \
    build 'path:/nextgen-lowram#packages.x86_64-linux.native-kms-gpu' --no-link --print-out-paths -L
```

Compare optimized `/nix/store/.../bin/.lenovo-native-mvp-wrapped` bytes, binary dependencies (`readelf` / `ldd`), total store closure, then—only with a watchdog and network access—measure actual PSS, i915 memory, RAM available, 30 taps and 5-minute idle on the tablet. Do not assume binary size equals resident RAM. Any live trial should automatically restore the exact generation 58 service/binary after bounded evaluation and retain physical GRUB 57/58.

### Reference installed gen58 numbers

- Process RSS ~80,640 KiB, PSS ~76,231 KiB (file PSS ~50,831, anonymous ~25,400).
- i915 graphics allocations ~39,444 KiB (cannot simply add to PSS).
- System `MemAvailable` ~1,475–1,489 MiB of 1,866 MiB; warm idle CPU ~0.5–1.4% sampled.
- No service restarts or GPU hangs; touch physically confirmed responsive by tablet owner.

## Actual builder and physical-device test (2026-10-21)

- Rebuilt `packages.x86_64-linux.native-kms-gpu` in the isolated two-job Mac Linux Nix builder; **build exit 0**, Cargo check exit 0. Actual Nix package `/nix/store/5i83bdnpvfnn81bcs8x6ij44iidc952m-lenovo-slint-kms-gpu-0.1.0`, binary imported and verified on the tablet without changing any NixOS profile.
- Installed gen58 ELF **6,909,464 bytes**; GPU-only ELF **6,239,672 bytes**: **669,792 bytes (9.69%) smaller**. Store package 6.7 MiB vs 6.0 MiB.
- 40-second source baseline from installed gen58: process PSS **~76,245 KiB**, Pss_Anon **25,400 KiB**, i915 graphics **39,444 KiB**, MemAvailable **~1,480–1,487 MiB**.
- Second controlled trial started the slim binary in place of the Slint service under an independent 90-second systemd restore timer, with **no change to generation 58, kernel, initrd or GRUB**. It logged `Using FemtoVG OpenGL renderer` and `Rendering at 1920x1200` and ran until a deliberate 30-second `timeout` exit 124. Slint service then restarted cleanly: **NRestarts=0**, all SSH/network/seatd units active, timer stopped.
- Trial PSS: **76,159 KiB after 8/21/27 seconds**, anon **25,260 KiB**—only ~86 KiB PSS less than the baseline, below meaningful system-level differences.
- i915 allocations: **30,212 KiB at 8 sec**, **40,508 KiB at 21 sec**, **40,548 KiB at 27 sec**. The apparent 9 MiB early graphics saving was a **transient framebuffer warmup difference**, not a persistent memory reduction.
- A physical touch test on this optional slim binary is **not claimed**; the original gen58 touch was already physically verified.
- Records: `gen58-baseline-corrected-40s.csv`, `gen58-lowram-smoke-extended.txt`, and the two scripts in `scripts/`.

**Conclusion:** retain the user's touch-proven GPU-accelerated **generation 58** as default. The alternative removes ~10% of disk executable size but did **not** materially reduce steady PSS or i915 GPU allocation. Do not install it as a new generation solely for this result. Future efforts should profile fonts/textures and buffer counts or consider service changes only after measuring user-value and hardware side effects.
