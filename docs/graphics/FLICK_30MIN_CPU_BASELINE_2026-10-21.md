# Flick compositor: 30-minute physical-tablet CPU baseline (original software-Qt stack)

Measurement completed on 2026-10-21. This is a **real sample of running NixOS generation 56 with original Flick**, not an optimised candidate. Data source: mvp/native/benchmarks/2026-10-21-flick-cpu-30min-baseline.csv. Script: tools/measure-flick-30min.sh; analysis: tools/analyze-flick-30min.py.

## Measurement outcome

The SSH sampling process collected 120 consecutive records, 15–16 seconds apart, spanning **1804 seconds (30.1 minutes)** from 2026-10-20T21:47:18Z to 22:17:22Z. The kernel HZ was 100. The recorded Flick, qmlscene and Slint dashboard PIDs remained stable throughout, Flick service was active, and its original wayland-1 socket remained present. No service restart, compositor activation, NixOS generation switch, UI brightness change or GPU reset was performed.

| Process | PID | Mean CPU use (100% = one logical core) | Median 15s CPU | Peak 15s CPU | Median resident memory |
|---|---:|---:|---:|---:|---:|
| Original Flick compositor | 894 | **91.8%** | 93.3% | 94.4% | 125.6 MiB |
| Qt 5.15 QML lock screen | 1026 | **33.7%** | 33.5% | 38.1% | 104.5 MiB |
| Native Slint dashboard | 5302 | **8.9%** | 9.5% | 11.1% | 42.5 MiB |

Qt had **four llvmpipe worker threads in every sample** (minimum, maximum and median all 4).

## Interpretation and limitations

These are deltas of Linux /proc process CPU jiffies divided by the corresponding wall-clock elapsed time. Values are per-one-core equivalent, not total device CPU percentage or GPU utilization. The screen was showing the usual lock-screen/dashboard workload; physical interaction and CPU frequency were not artificially controlled. Brief read-only EGL diagnostics were performed during part of this baseline, which can add small normal system load. The original Flick session was not replaced.

Total nominal CPU use of these three processes is approximately 134.4% of one logical core, but this does not include kernel/system activities. The baseline is therefore useful for repeated identical-workload comparisons with one optimized candidate at a time, not evidence of improvement.

A later controlled trial should record the identical jiffy/RSS fields, check whether wl_drm and zwp_linux_dmabuf_v1 appear, confirm Qt eglinfo and QSG rendering use Intel Crocus (not llvmpipe), inspect all four QML threads, and test touch/keyboard/unlock. Source-level compilation alone is not a fair A/B replacement for this measured live baseline.
