# Timed combined Flick EGL/QML stability trial

Observed runtime sample window: **305 seconds**, 31 samples.
All sampled Flick/QML PIDs stayed constant, Flick service and Wayland socket were present, and QML llvmpipe workers remained at zero.

| Process | CPU (of one core) | Start RSS | End RSS | Peak RSS | RSS change |
|---|---:|---:|---:|---:|---:|
| flick | 15.3% | 134.5 MiB | 134.5 MiB | 134.5 MiB | +0.0 MiB |
| qml | 13.3% | 123.8 MiB | 124.6 MiB | 124.6 MiB | +0.8 MiB |

Combined sampled Flick+QML CPU: **28.6% of one core**.

These /proc readings do not establish physical display correctness, actual frame rate, render latency or a memory-leak-free long-term service. The timed rollback must be checked separately.
