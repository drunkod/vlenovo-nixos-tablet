# Nix-store packaged Flick GPU candidate: built, transferred and validated

Date: 2026-10-21. Dedicated Git branch: flick-gpu-optimization.

## Reproducible package

- Nix flake output: packages.x86_64-linux.flick-qt-egl-qml-system
- Output path: /nix/store/k7rf872zph2192khxyrvx7fgzj40fl1r-flick-qt-egl-qml-system
- Unwrapped tested fifth Flick executable: /nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04
- ELF SHA-256: 4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d, verified byte-for-byte identical to the live-tested staged executable
- Assets path: /nix/store/m3dw24bsmv6d1v4pq66slnc5nzn1dkmy-flick-assets-unstable-2026-01-04, **identical to the working tablet's existing NixOS Qt assets**
- Wrapper: original Flick NixOS FLICK_ROOT and Mesa/GBM/GLVND/Wayland library paths maintained
- Build: MacBook Colima x86_64 Linux via Rosetta, Nix 2.28.4, exit 0, no new Rust compilation
- Nix-store verification on Mac builder: PASS
- Wrapper --help on Mac and on real tablet: PASS

The built package's exact two store outputs (new wrapper + the same previously tested unwrapped Flick derivation) were transferred from the Mac's Nix store to the tablet using a binary NAR export/import over authorized SSH. The tablet confirmed both new paths valid in /nix/store. The only direct dependencies not already in the tablet's store were those two new outputs; the other thirteen direct references were checked before import.

The old and optimized packages each have **282 closure paths**. The only difference is two paths: the old wrapper + original Flick ELF versus the new immutable wrapper + GPU-optimized Flick ELF. All Qt5 QML assets, runtime libraries, kernel-side dependencies and other Nix-store closure references are identical. This comparison was verified on the tablet, not assumed from the Nix expression.

A registered Nix garbage-collection root preserves the optimized package:
- /home/alex/lenovo-mvp/builds/.flick-qt-egl-qml-system-gcroot

Read-only repeatable checks: tools/verify-flick-immutable-system-package.sh.
Measured tablet transcript: mvp/native/benchmarks/2026-10-21-flick-immutable-nixos-package-verified.txt.

## NixOS generation integration

The actual tablet-side Flick module at /home/alex/vlenovo-flick-dev/modules/nixos/flick/default.nix defines services.flick.package and uses that package for the NixOS systemd ExecStart and FLICK_ROOT. The active /etc/systemd/system/flick.service file is a symlink to an immutable /nix/store/...-unit-flick.service/flick.service; contrary to the first inference based on systemctl's FragmentPath, it is a NixOS-managed unit. This gives a declarative path to making the package a future generation.

However, /etc/nixos/configuration.nix is an older SXMO-oriented configuration and does not directly prove the current vlenovo generation's source provenance. An attempted read-only evaluation of /home/alex/vlenovo-flick-dev's NixOS flake was stopped because cold Nix evaluation used roughly 1.3 GiB RAM on the tablet's 2 GiB machine. It did not produce an authoritative equality result; the evaluator was terminated cleanly and the device's free memory recovered. Full NixOS evaluation should be offloaded to the MacBook and matched to the known-good current system store path before producing or activating a new generation.

## Safety state

The immutable system package was **not installed as a new NixOS generation** and the normal service was not changed in this packaging step. Following the previous three live trials, all systemd rollback timers completed with Result=success; the default Flick compositor was restored (PID 18715), no /run Flick override remained, SSH/NetworkManager/seatd were active, and current/booted NixOS generation links matched.

Hardware acceleration and large CPU improvements were directly proven in the live short A/B and 305-second combined soak; physical screen pixels, touch/unlock, rotation, suspend/resume and extended stability remain unverified. The next step is an offloaded matching NixOS generation build and a controlled visual/touch acceptance test before permanent promotion.
