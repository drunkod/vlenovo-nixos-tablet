# Full-frame RGBA allocation/copy microbenchmark

The observed original Flick Slint path allocates/copies a 1920x1200 RGBA image when the external QML lock screen is active, even though the QML branch does not use that Slint render element. For each frame, 1920*1200*4 = 9,216,000 bytes (~8.79 MiB). The path constructs a cloned pixel vector and then writes it into a MemoryRenderBuffer. At 5.7 observed renders per second the explicitly duplicated copy components move at least 2*9,216,000*5.7 ~=105 MB/s, excluding allocation initialization and actual Slint painting. This is a calculated byte count, not a measured device memory bandwidth.

The new tools/bench-flick-rgba-copy.py is a bounded Python user-memory analogue that allocates/copies two full-frame buffers repeatedly and measures process CPU time and wall time. Run on the Lenovo after CPU tracing, while not using the display, KMS, libseat, input sensors or compositor. Report CPU milliseconds per RGBA copy sequence and copy-rate estimate. It cannot measure Slint render, renderer import, Wayland or GPU behavior, and must not be used to claim a production CPU saving.

The fifth candidate includes the previously built QML raster guard and hardware EGL protocol fixes, all remaining unactivated.
