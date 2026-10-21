# Lenovo tablet Flick graphics: extended real-device and Mac VM testing session

Date: 2026-10-21. Dedicated branch: flick-gpu-optimization.

## Goal and scope

Continue Flick GPU optimization without requiring the tablet owner to intervene. Test the independent native DRM QML Slint raster-skip + EGL wl_drm + validated Linux DMA-BUF candidate, its package and its recovery strategy. Use MacBook's CPU for builds. Avoid unverified changes to the working NixOS generation or the DRM compositor.

The separate fifth candidate was already compiled successfully from the same pinned upstream Flick commit and patch stack: x86_64 Linux Nix output /nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04, binary SHA-256 4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d. This session ran additional tests rather than changing the production driver or bootloader.

## Results table

| Test | Outcome | Evidence |
|---|---|---|
| Nix flake evaluation of all five original candidate outputs plus separate test derivation | PASS | Nix 2.28.4 flake check --no-build |
| x86_64 Rust test-only Nix build of identical combined source and patch stack | PASS | FLICK_COMBINED_RUST_UNIT_TEST_RESULT_2026-10-21.md |
| Rust unit tests | 10 passed, 0 failed, 0 ignored | mvp/native/benchmarks/2026-10-21-flick-combined-rust-unit-tests.txt |
| Nix test build store integrity | PASS | /nix/store/1k1axvnaxkac9sfq8ps5vjx96qwhifxx-flick-unstable-2026-01-04 |
| Intel Bay Trail OpenGL ES2 framebuffer clear/readback on physical tablet (64x64) | PASS, eight frames each run | INTEL_BAYTRAIL_GLES_OFFSCREEN_TEST_2026-10-21.md |
| Three repeated GPU draw/readback runs | PASS, 24 additional frames | mvp/native/benchmarks/2026-10-21-intel-gles2-offscreen-repeat.txt |
| EGL renderer | Mesa Intel(R) HD Graphics (BYT), OpenGL ES 3.0, Mesa 25.0.7 | mvp/native/benchmarks/2026-10-21-intel-render-node-gles2-draw-readback.txt |
| Explicit LIBGL_ALWAYS_SOFTWARE=1 negative-control attempt | INCONCLUSIVE: GBM still chose Intel hardware | mvp/native/benchmarks/2026-10-21-intel-gl-software-fallback-negative-control.txt |
| Actual systemd SYSTEM-level marked rollback timer on isolated Ubuntu Colima VM | PASS | FLICK_REAL_SYSTEMD_VM_ROLLBACK_2026-10-21.md |
| Real systemd experimental start failure followed by timed rollback | PASS | mvp/native/benchmarks/2026-10-21-systemd-vm-crashed-service-recovery.txt |
| Timer survival after originating command/remote connection exited | PASS | mvp/native/benchmarks/2026-10-21-systemd-vm-disconnected-initiator-recovery.txt |
| Refusal of missing/unmarked/symlinked override | PASS in VM | mvp/native/benchmarks/2026-10-21-systemd-vm-rollback-rehearsal.txt |
| Pinned Smithay EGL buffer, ImportAll and DMA-BUF notifier source contract | PASS | tools/check-flick-smithay-egl-integration.py |
| Four deliberately corrupted Smithay contracts rejected | PASS | tools/test-flick-smithay-source-contract.py |
| Combined native DRM Slint+EGL+DMA-BUF source predicates and ordering | PASS | tools/check-flick-combined-source.py |
| All five candidate binary SHA-256 hashes and Nix-compatible launcher SHA-256 hashes | PASS | mvp/native/benchmarks/2026-10-21-five-flick-candidates-and-wrappers-preflight.txt |
| All five candidate --help smoke tests under preserved Flick NixOS wrapper environment | PASS | mvp/native/benchmarks/2026-10-21-five-nix-runtime-wrapper-smoke.txt |
| Original production compositor activation in this session | NOT PERFORMED | MainPID remained 894, original NixOS boot/current generation unchanged |

Two completed, independent original-system 30.1-minute CPU baselines and a 26-minute temperature/frequency sampling window are preserved separately in FLICK_REPEAT_BASELINE_THERMAL_RGBA_RESULT_2026-10-21.md. Flick averaged 91.8% and 92.4% of one logical CPU core; QML averaged 33.7% and 33.6%, with four llvmpipe workers in all samples. The median recorded CPU TCPU temperature was 67°C. These are original-compositor baselines, NOT measurements after installing the fifth candidate.

## Important distinctions

1. The Intel driver does not need to be ported from Windows to accomplish normal accelerated GLES rendering on the Bay Trail GPU. Existing Linux i915 and Mesa Crocus hardware functionality was demonstrated by actual GL drawing/readback with the original compositor alive.
2. The private Wayland EGL A/B from the preceding research proved that enabling EGL's wl_drm binding is sufficient for a minimal Wayland client to obtain the Intel renderer. The current session's source audit checked the matching feature-gated Smithay integration and Rust tests.
3. A separate production Flick launch test is still required to establish that the QML lock screen attaches working EGL/dmabuf buffers and reduces CPU use without breaking touch/unlock/keyboard. The new Nix release package and launchers are staged on the tablet but are NOT the active compositor.
4. The real systemd root-manager rollback and failure injection were performed inside an isolated Mac-hosted Linux VM. Those tests cannot prove the actual Lenovo display/seat subsystem will automatically recover after a bad compositor switch. Earlier Remote Desktop Commander tool constraints prevented activating the privileged tablet service; they were not modified or bypassed.
5. Do not infer performance savings by multiplying the Python RGBA memory-copy benchmark into GPU compositor CPU improvement. The QML lock screen still uses the original running binary, as indicated by PID and boot generation.

## Next trial conditions

A true comparison needs a trusted system-manager-safe temporary activation environment with guarded timer rollback, a read-only Wayland registry check for wl_drm and zwp_linux_dmabuf_v1, Qt EGL actual renderer diagnostics, visual/touch/keyboard/unlock checks, and fresh CPU jiffy traces. Distinguish the fourth EGL-only candidate from the fifth EGL+QML candidate. The benchmark should check thermal/frequency effects and automatically restore the original generation/service after the time-bounded trial. Do not disable connector safety controls to force deployment.

All source, diagnostic scripts and results are versioned on flick-gpu-optimization. The original owner's separate worktree was not modified.
