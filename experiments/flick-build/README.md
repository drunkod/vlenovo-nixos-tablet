# Reproducible Flick GPU/logging package experiment

This directory builds a **standalone, x86_64-linux Flick package**. It is not a NixOS system configuration and has no activation, installation, compositor restart or boot switch actions.

## Provenance

- Base source: `ruapotato/Flick` commit `729cdecedad05be3192b21f7d4310eb0ff7ae563`.
- The upstream `shell/src/backend/udev.rs` SHA-256 at that commit is `5271c31e988f699f988bc23a14e5befc3204e223fede689508e5c713cd3d32fd`, **matching** the corresponding file in deployed Nix source `/nix/store/9yljxq5k9sbjrnc9w6db6fwnlndhpb32-source` on 2026-10-20.
- Packaging/first six patches come from the **known-good** `flick-status-telemetry` Git revision `a3dcc06`; Rust lockfile is preserved.
- Seventh patch (`patches/flick/0007-throttle-render-info-logs.patch`) is the isolated log-level-only patch from `../../patches/flick/0001-throttle-render-info-logs.patch`.
- Nixpkgs and newer Rust toolchain inputs are pinned by the copied `flake.lock`. The built package uses NixOS 25.05 dependencies, the same Rust override, and two concurrent Cargo jobs.

## Verification and build

From the optimisation branch:

```bash
cd experiments/flick-build
nix eval --raw .#packages.x86_64-linux.flick.name
nix build .#packages.x86_64-linux.flick --no-link --print-out-paths -L
```

The seven-patch sequence was independently checked on the MacBook by archiving upstream commit `729cdece…` from `.local/references/Flick`, then applying the six original NixOS patches followed by the new logging patch. Every `git apply --check` passed in order. The packaged source also uses its pinned `fetchFromGitHub` hash; it can build independently of the local source checkout when Nix has network access.

**Build platform:** x86_64 Linux. This MacBook is ARM64 Darwin; its `builders` setting currently points at `@/etc/nix/machines` but that file is absent in the visible environment. A successful Nix evaluation or `--dry-run` does *not* mean a working x86_64 Linux build worker exists. Configure/attach an authorised Linux builder before attempting a Mac-initiated full build, or compile the package on the tablet using two jobs when an appropriate maintenance window is available. Do not infer this is a cross-compiled ARM64 binary.

## What this patch does

Downgrades 30 high-frequency render-function INFO messages to DEBUG, preserving WARN/ERROR. The live source emits roughly 7 KB/s of logging and runs Flick near 90% of one Atom core in short idle samples; those are **pre-patch baselines**. The measured runtime speed-up from this patch is **unknown**.

This is the first low-risk CPU optimisation candidate, not the large redraw/cache refactor. For any future touch-visible test, check the candidate's exact derivation and binary hash, preserve existing SSH and boot generation, arrange local recovery, and obtain approval before intentionally restarting Flick. A compositor restart interrupts the active tablet session; merely building in Nix store does not.

See `../../docs/graphics/FLICK_RENDER_LOGGING_EXPERIMENT.md` and `../../mvp/native/benchmarks/2026-10-20-flick-render-log-baseline.txt`.
