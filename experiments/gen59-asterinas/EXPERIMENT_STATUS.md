# Gen59 Asterinas DRM VM experimental status

2026-10-21, MacBook QEMU laboratory. **No actual tablet generation 59 and no tablet boot changes.**

- Baseline physical generation 58 is frozen on the separate branch `lenovo-gen58-slint-kms-gpu-touch-golden-2026-10-21`, commit `8a422fd`; physically touch-verified by owner, ~1.5 GiB available RAM, GPU accelerated.
- Exact Asterinas source tag `v0.19.0` resolves to commit `c4b7ed575b7b32773475b194d2ad41fb6d03765b`.
- Official ISO asset SHA-256 from GitHub Release API `7df9fafed4fe886e44bda501834937d893e12a05af911fabeb068c34379fb86e`, length 1,442,840,576 bytes. This ISO is stored **outside Git**, locally under `.local/archives/` after verified download.
- VM-only Mac launcher: `scripts/boot-official-iso-macos.sh`, x86_64 TCG, 3072 MiB RAM, VNC 127.0.0.1 only, read-only installation ISO; no host disk exposed.
- Core Asterinas Rust DRM and `simpledrm` read at the pinned Git commit: simpledrm registers a virtual connector and `DrmFeatures::empty()`; GPU render node, Intel i915 DSI and ELAN1001 native touch remain unsolved. This is a real technical reason against promoting to physical gen59 now.
- Mac has Apple Silicon so **cannot accelerate an x86_64 guest with KVM**; Colima/Rosetta Linux builder likewise has no `/dev/kvm`. QEMU software TCG boot will be slow. Upstream NixOS examples expect up to 8GiB RAM, above tablet hardware.
- `RAM_OPTIMIZATION.md` records the baseline and lightweight Slint tweaks for separate low-RAM branch.
- Status to update only after QEMU boots and actual tests: **Official Asterinas ISO VM test not yet confirmed successful**. Do not conflate successful source audit or downloaded ISO with boot verification.
