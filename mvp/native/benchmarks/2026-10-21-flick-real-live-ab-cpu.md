# Flick physical tablet live graphics A/B CPU report

| Variant | Sample span | Flick CPU | QML CPU | Sum | QML llvmpipe workers |
|---|---:|---:|---:|---:|---:|
| Original 30-min baseline A | 1804 s | 91.8% | 33.7% | 125.5% | 4 |
| Original 30-min baseline B | 1804 s | 92.4% | 33.6% | 125.9% | 4 |
| Qt EGL-only live | 56 s | 92.7% | 2.2% | 94.9% | 0 |
| Qt EGL + QML skip live | 87 s | 15.5% | 13.4% | 28.8% | 0 |

Original combined CPU baseline mean: 125.7% of one logical core.
EGL-only combined CPU change vs original: -24.5%.
EGL+QML combined CPU change vs original: -77.1%.
Flick-only CPU change with combined candidate: -83.2%.

Note: percentages are additive per-process CPU time, normalized to one logical core. Baseline spans 30 minutes each, while candidate trials last under 90 seconds; workload animation, CPU frequency and temperature are not precisely controlled. No visual/touch input correctness check was possible over SSH. No inference of sustained energy savings or compositor frame correctness. Both candidates were restored automatically via a root/systemd timer.
