# Tablet thermal and clock-rate context

Span: 283 seconds, 15 samples.
Active Flick PID 17078 was stable.

| Probe | Minimum | Median | Maximum |
|---|---:|---:|---:|
| CPU TCPU | 64.0°C | 65.0°C | 65.0°C |
| SoC DTS0 | 62.0°C | 62.0°C | 62.0°C |
| SoC DTS1 | 63.0°C | 63.0°C | 64.0°C |
| cpu0_khz | 533 MHz | 1418 MHz | 1867 MHz |
| cpu1_khz | 533 MHz | 1389 MHz | 1867 MHz |
| cpu2_khz | 586 MHz | 1466 MHz | 1700 MHz |
| cpu3_khz | 1052 MHz | 1467 MHz | 1867 MHz |

Samples with core frequency below 1500 MHz: 48 of 60 (80.0%).
AC mains online in 15 of 15 samples; battery charge range 98–98%.

A low frequency reading does not itself establish thermal throttling: CPUfreq governors change clocks for other reasons. This is an observational workload/temperature context, not a power-efficiency benchmark.
