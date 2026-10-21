# Real Lenovo NixOS compositor integration: six-minute Flick GPU/Slint soak

Date: 2026-10-21. Branch: flick-gpu-optimization. The tablet owner explicitly approved live temporary activation and GRUB recovery risk. The test was run on the real Intel Bay Trail tablet, not an offscreen Qt or VM simulation.

## Exact tested candidate and rollback

The independent fifth Flick candidate has Linux x86_64 binary SHA-256 4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d. Its original-NixOS-runtime-preserving launcher SHA-256 is 03c4d9c73be4475648feae827d53a31f55d7893c399dd0e99be661448c430e22. The code combines the QML-obscured Slint software raster skip (patch 0008), native GPU DMA-BUF import/feedback validation (0009) and Wayland EGL wl_drm binding (0010), with all previous NixOS/Flick patches.

The script tools/flick-supervised-live-trial.sh checked exact hashes, NixOS generation, service status and GRUB generation 55 recovery files. It armed a **360-second root systemd rollback timer before service restart**, then installed only a temporary /run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf drop-in overriding ExecStart. The original /etc/systemd/system/flick.service remained unchanged.

Flick PID **17078** started at 04:22:24 UTC, QML PID **17113**. The Wayland server exposed wl_drm version 2 and zwp_linux_dmabuf_v1 version 5. QML had four open /dev/dri/renderD128 descriptors and **zero llvmpipe worker threads** in early and late checks. No Flick automatic restarts or journal errors were observed.

At approximately 04:28:26 UTC, the independently armed systemd rollback returned Result=success, deleted the ephemeral service override, reloaded systemd and restarted the original NixOS-wrapped Flick executable. Original Flick PID **18715** was verified active afterwards; QML had again switched to four llvmpipe worker threads. SSH, NetworkManager, seatd and Flick were all active, and the booted/current NixOS generations remained identical. **All three** real tablet rollback timer service results—EGL-only, EGL+QML short, EGL+QML soak—were success. Proof: mvp/native/benchmarks/2026-10-21-live-flick-three-systemd-rollbacks.txt.

## Sustained CPU and memory measurements

Read-only /proc jiffy samples every 10 seconds for 305 seconds, 31 samples, collected while the **actual combined compositor** was active:

| Metric | Observation |
|---|---:|
| Flick CPU | 15.3% of one logical core |
| QML CPU | 13.3% of one logical core |
| Flick + QML sum | 28.6% of one logical core |
| Flick RSS start/end/peak | 134.5 / 134.5 / 134.5 MiB |
| QML RSS start/end/peak | 123.8 / 124.6 / 124.6 MiB |
| QML llvmpipe workers | 0 throughout all 31 CPU samples |
| Flick/QML PID changes | None |
| Service / Wayland socket interruptions | None |

The two original 30.1-minute baselines measured roughly 125.5% and 125.9% one-core equivalent Flick+QML CPU. The combined live 87-second A/B measured 28.8%, and this longer 305-second soak measured 28.6%. These observations correspond to approximately **77% less combined Flick+QML CPU use than the original baseline** during the measured idle QML-lock workload. Flick itself fell from approximately 92% to 15.3% one-core CPU. The separately tested EGL-only candidate kept Flick near 92.7% but QML at 2.2%, vs QML at 13.3% here; the difference deserves investigation of animation/render update cadence and actual displayed frames.

Raw CPU trace: mvp/native/benchmarks/2026-10-21-flick-combined-five-minute-soak-cpu.csv. Validated tool: tools/analyze-flick-live-soak.py, with deliberate PID-change/incomplete-trace/software-fallback negative tests. Derived result: mvp/native/benchmarks/2026-10-21-flick-combined-five-minute-soak-report.md.

## Thermal and CPU frequency

A concurrent 283-second read-only thermal and core-clock trace included 15 samples: CPU TCPU temperature 64–65°C (median 65°C), SoC DTS0 62°C, DTS1 63–64°C. All samples had mains power online and battery at 98%. CPU governor frequencies varied from about 533 MHz to 1.87 GHz, with most below 1.5 GHz; this is **not proof of thermal throttling**. Compared with an original-baseline CPU median near 67°C, the new workload may be cooler, but thermals, ambient conditions, animation state and time of day were not controlled.

Raw thermal trace: mvp/native/benchmarks/2026-10-21-flick-combined-five-minute-soak-thermal.csv. Analysis: mvp/native/benchmarks/2026-10-21-flick-combined-five-minute-soak-thermal-report.md.

## Protocol diagnostics

The Wayland registry was audited early and late in the real six-minute trial:
- mvp/native/benchmarks/2026-10-21-flick-combined-soak-wayland-early.txt
- mvp/native/benchmarks/2026-10-21-flick-combined-soak-wayland-late.txt

Both samples found wl_drm and zwp_linux_dmabuf_v1 present, zero QML llvmpipe threads, four DRM render node handles, and all essential services active.

## Safety, limitations and next engineering step

The test establishes GPU client protocol advertisement, effective QML render-node use, compositor liveness, sustained sampled CPU/RSS and actual successful rollback on the tablet. It does NOT validate correct pixels on the physical screen, touch/unlock interaction, onscreen frame rate, screen rotation, display hotplug, suspend/resume or all possible buffer import modifiers. Such visual and physical interactions remain **unverified** over this SSH-only connection, even though processes remained active without reported errors. Do not promote purely based on CPU percentage.

A critical deployment detail: the working Flick unit resides at /etc/systemd/system/flick.service, not inside a NixOS-managed /nix/store unit definition. Arbitrary permanent /etc edits would **not necessarily be undone by selecting a different GRUB generation**. Therefore all three activation tests deliberately used only removable /run drop-ins and an independently armed root systemd rollback timer; no /etc unit, GRUB, boot/current generation or profile was changed. The fifth candidate remains a staged executable, not the current service.

The recommended next implementation step is packaging this exact fifth Flick output and lockscreen assets declaratively in a **new NixOS system generation**, testing actual touch/unlock/display behavior and retaining an independent timed rollback before promoting it as default. The original OS remains bootable and the MacBook builder keeps its cache.
