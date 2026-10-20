# Fifth Flick build session: repeat idle CPU baseline, temperature and RGBA memory-copy test

All tests completed on 2026-10-21 using the actual Lenovo Miix 2 10 running its original, unmodified NixOS Flick service. The new fifth Flick candidate was compiled and staged, NOT activated. These measurements therefore establish baseline stability and memory-copy overhead, but they do NOT measure the new candidate’s CPU saving.

## Independent 30-minute original-compositor CPU baseline

Raw dataset: mvp/native/benchmarks/2026-10-21-flick-second-30min-cpu-baseline.csv. Exact same read-only Linux /proc jiffy methodology as the first run mvp/native/benchmarks/2026-10-21-flick-cpu-30min-baseline.csv. Samples taken at ~15 seconds; process identities, active service and Wayland socket checked.

# Read-only Flick CPU trace

Duration: **1804s** (30.1 minutes), **120** samples, jiffy counter clock 100Hz.
Start (UTC): 2026-10-20T22:29:50Z. End: 2026-10-20T22:59:54Z.
All three process IDs remained stable; Flick service active and Wayland socket present in every sample.

| Process | Mean CPU (one core = 100%) | Median 15s CPU | Peak 15s CPU | Median RSS |
|---|---:|---:|---:|---:|
| flick (PID 894) | 92.4% | 93.3% | 94.1% | 125.1 MiB |
| qml (PID 1026) | 33.6% | 33.7% | 36.9% | 106.0 MiB |
| native (PID 5302) | 8.9% | 9.5% | 10.8% | 42.5 MiB |

QML llvmpipe worker threads: min=4, max=4, median=4.

These are CPU-jiffy deltas averaged over the sampling period, not GPU-utilisation or instantaneous frequency readings. Screen/user activity and CPU frequency are not controlled. No optimized candidate was activated during this baseline.

## Stability comparison against the first untouched 30-minute run

# Original Flick repeat-baseline stability

Both independent traces were collected from the original running Flick; neither uses an optimized candidate.
First trace: 1804s, 120 samples. Second trace: 1804s, 120 samples.

| Process | Baseline 1 mean CPU | Baseline 2 mean CPU | Absolute delta | 5-min range (baseline 1) | 5-min range (baseline 2) | Median RSS 1 / 2 |
|---|---:|---:|---:|---:|---:|---:|
| flick | 91.8% | 92.4% | +0.6 pp | 88.7–92.6% | 92.2–92.6% | 125.6 / 125.1 MiB |
| qml | 33.7% | 33.6% | -0.2 pp | 33.5–34.3% | 33.1–34.1% | 104.5 / 106.0 MiB |
| native | 8.9% | 8.9% | -0.0 pp | 8.4–9.3% | 8.3–9.4% | 42.5 / 42.5 MiB |

QML llvmpipe worker counts seen: baseline 1 [4]; baseline 2 [4].

CPU percentages refer to a single logical core (100%=one fully busy core). Five-minute ranges are observed variation, not 95% confidence intervals. Physical workload, CPU frequency, background interrupts and thermals were not controlled. Changes after installing a candidate must therefore be assessed using repeated comparable measurements and graphics correctness, not just a single CPU percentage.

## Concurrent read-only temperature and CPU frequency observations

Raw sensor and clock dataset: mvp/native/benchmarks/2026-10-21-flick-repeat-thermal-cpu-frequency.csv. The trace covered 1569 seconds of the second baseline. TCPU is the kernel thermal_zone5 value; some other thermal-zone values on this tablet are invalid and are deliberately excluded. Sensor reads did not touch the shared ALS hub, reset sensors, change thermal policy or brightness.

# Tablet thermal and clock-rate context

Span: 1569 seconds, 53 samples.
Active Flick PID 894 was stable.

| Probe | Minimum | Median | Maximum |
|---|---:|---:|---:|
| CPU TCPU | 66.0°C | 67.0°C | 68.0°C |
| SoC DTS0 | 61.0°C | 61.0°C | 62.0°C |
| SoC DTS1 | 63.0°C | 64.0°C | 64.0°C |
| cpu0_khz | 1420 MHz | 1867 MHz | 1867 MHz |
| cpu1_khz | 1403 MHz | 1867 MHz | 1867 MHz |
| cpu2_khz | 534 MHz | 1867 MHz | 1868 MHz |
| cpu3_khz | 669 MHz | 1867 MHz | 1867 MHz |

Samples with core frequency below 1500 MHz: 36 of 212 (17.0%).
AC mains online in 53 of 53 samples; battery charge range 98–98%.

A low frequency reading does not itself establish thermal throttling: CPUfreq governors change clocks for other reasons. This is an observational workload/temperature context, not a power-efficiency benchmark.

## Full-resolution user-memory clone/copy benchmark (after baseline)

Original Slint paints to a 1920x1200 RGBA pixel buffer and, in the obscured QML path, clones the pixels and writes them to a MemoryRenderBuffer even though that Slint image is not included in the QML-only render branch. This separate bounded Python test allocates/clones and copies an equivalent-size byte buffer, measuring process CPU time. It ran only AFTER both read-only CPU/thermal monitors finished, ensuring no contamination of the original idle baseline.

Raw result: mvp/native/benchmarks/2026-10-21-flick-rgba-copy-tablet.txt.

Measured output:

    mode=allocate_clone_and_copy width=1920 height=1200 bytes_per_frame=9216000 repeats=3 frames_each=120
    repeat,frames,elapsed_wall_s,elapsed_cpu_s,cpu_ms_per_frame,minimum_user_copy_mib_per_s
    1,120,1.1703,1.1337,9.4476,1802.4
    2,120,1.1991,1.1536,9.6132,1759.1
    3,120,1.1781,1.1412,9.5102,1790.5
    median_cpu_ms_per_frame=9.5102
    checksum_parity=127
    NOTE: only Python allocation/memory copy; NOT Slint or GPU benchmark

The observed median 9.5102 ms/frame is for Python allocations and memory copies. It is NOT a measurement of Flick Slint render time, compositor frame duration, GPU bandwidth or the speed-up achieved by the fifth candidate. The older 57 full Slint renders in 10 seconds suggests possible opportunities, but should not be multiplied into a claimed performance gain. A live guarded graphics trial and additional CPU traces would be required for that.

## Build state and safety at the end

Fifth combined release Nix output /nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04, SHA-256 4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d, has passed two-thread Mac x86_64 Linux release compilation, Nix integrity, signature and dependency checks, laptop/tablet --help, tablet staging and original-runtime-wrapper test. All five candidates separately pass the tablet read-only preflight (see docs/graphics/FLICK_FIFTH_BUILD_RESULT_2026-10-21.md).

No compositor or NixOS generation switch was performed. Original Flick remained active PID 894 with no systemd trial override after the RGBA benchmark. The MacBook’s dedicated build VM was stopped with its Nix store cache intact. A real fourth/fifth compositor A/B still requires a privileged system-service rollback integration that the Remote Desktop Commander command policy has blocked; no controls were changed or bypassed.
