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
nix --option sandbox false --option filter-syscalls false \
  --option max-jobs 2 --option cores 2 \
  build .#packages.x86_64-linux.flick.unwrapped --no-link --print-out-paths -L
```

The seven-patch sequence was independently checked on the MacBook by archiving upstream commit `729cdece…` from `.local/references/Flick`, then applying the six original NixOS patches followed by the new logging patch. Every `git apply --check` passed in order. The packaged source also uses its pinned `fetchFromGitHub` hash; it can build independently of the local source checkout when Nix has network access.

**Build platform:** x86_64 Linux. On 2026-10-21 a dedicated Colima VZ/Linux VM with Rosetta x86_64 emulation was successfully started on the ARM64 MacBook, and an x86_64 Linux Nix 2.28.4 container was verified. The candidate build was started inside that container with two concurrent jobs. See `../../docs/graphics/MAC_LINUX_FLICK_BUILDER_2026-10-21.md` for exact setup, logs, and current outcome. This is an x86_64 Linux guest build using MacBook CPUs; it is not an ARM64 Darwin binary. Source evaluation alone does not demonstrate a successful binary build.

## What this patch does

Downgrades 30 high-frequency render-function INFO messages to DEBUG, preserving WARN/ERROR. The live source emits roughly 7 KB/s of logging and runs Flick near 90% of one Atom core in short idle samples; those are **pre-patch baselines**. The measured runtime speed-up from this patch is **unknown**.

This is the first low-risk CPU optimisation candidate, not the large redraw/cache refactor. For any future touch-visible test, check the candidate's exact derivation and binary hash, preserve existing SSH and boot generation, arrange local recovery, and obtain approval before intentionally restarting Flick. A compositor restart interrupts the active tablet session; merely building in Nix store does not.

See `../../docs/graphics/FLICK_RENDER_LOGGING_EXPERIMENT.md` and `../../mvp/native/benchmarks/2026-10-20-flick-render-log-baseline.txt`.

## Confirmed binary build

The Mac-hosted Rosetta x86_64 Linux build **completed successfully** on 2026-10-21 with the logging-only seventh patch. Nix result: `/nix/store/3j68fnhw24dz4vnxhijhngq7923nn4lw-flick-unstable-2026-01-04`, validated tablet-staged binary SHA-256 `ad01f34e4576f0b8d6a8254835884758179df40923cb377564c0fc4c7dc2f7f6`. For the first build, a 3 GiB swap file was temporarily required inside the VM during final Rust code generation. The unactivated and still-unmeasured result, execution details and future rollback requirements are documented in `../../docs/graphics/FLICK_MAC_BUILD_RESULT_2026-10-21.md`.

## Separate QML-only experimental build target (2026-10-21)

The flake now preserves two distinct outputs. `flick.unwrapped` remains the **logging-only** build that succeeded and was staged. The new `flick-qml-experimental` output applies an **eighth** patch *after* the seven known patches and does not alter the default package:

```bash
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
  --option sandbox false --option filter-syscalls false \
  --option max-jobs 2 --option cores 2 \
  build 'path:/work#packages.x86_64-linux.flick-qml-experimental' \
  --no-link --print-out-paths -L
```

The experimental derivation evaluates and the actual Nix patch phase **successfully applied all eight patches** on 2026-10-21. Cargo began building the new release candidate. This does not imply runtime safety or measured power/CPU improvement. The QML patch is scoped to skipping unused full-screen Slint rasterisation when the existing QML lock-screen rendering branch is selected. Slint event processing and its keyboard overlay path are preserved.

### Repeatable non-destructive artifact check

From the worktree root, `tools/verify-flick-built-candidate.sh logging` verifies the already-built logging-only Nix output path, ELF architecture, SHA-256 and `--help` smoke test. After the experimental build finishes, use `tools/verify-flick-built-candidate.sh qml` for an identical check. Either mode accepts the **explicit** `--stage` flag to copy its verified binary to the tablet's unprivileged `~/lenovo-mvp/builds/` directory, verify matching checksums, run `--help`, and confirm essential services remain up. The tool **never activates**, restarts or replaces Flick and **never changes** the tablet's NixOS generation.
