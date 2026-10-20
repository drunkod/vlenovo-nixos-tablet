# Flick logging candidate — successful MacBook x86_64 build (2026-10-21)

## Result

**Build succeeded** for the isolated **logging-only** candidate on Git branch `flick-gpu-optimization` (source state `68b1443`). Nix exited **0**, completed installation and ELF fix-up, and its store output passed `nix-store --verify-path`. The running Lenovo compositor was **not** restarted or replaced. The logging patch has **not** yet been benchmarked in the live DRM session.

| Property | Verified value |
| --- | --- |
| Upstream Flick commit | `729cdecedad05be3192b21f7d4310eb0ff7ae563` |
| Patch sequence | Six NixOS integration patches + seventh 30-site INFO-to-DEBUG logging patch |
| Separate follow-up QML/Slint optimisation | **Excluded** from this build |
| Builder | MacBook Colima profile `vlenovo-flick-build`, aarch64 Linux VZ VM + Rosetta x86_64 emulation |
| Builder resources | 4 vCPUs, 6 GiB RAM, 26 GiB Docker disk; Nix/Cargo at 2 parallel jobs |
| Nix userspace | `nixos/nix:2.28.4` Linux/amd64 Docker container `vlenovo-flick-nixbuild` |
| Compilation flags | `--target x86_64-unknown-linux-gnu --offline --profile release -j 2` |
| Rosetta-only Nix workaround | `--option sandbox false --option filter-syscalls false` inside isolated container |
| Rust crate compilation events | 379 |
| Cargo release build duration | **22 minutes 51 seconds** |
| Compiler warnings | 135; build successful, no fatal errors |
| Nix store output | `/nix/store/3j68fnhw24dz4vnxhijhngq7923nn4lw-flick-unstable-2026-01-04` |
| Nix closure size | 125 store paths |
| ELF | 64-bit x86-64 Linux PIE executable, approximately 38 MiB |
| Executable SHA-256 | `ad01f34e4576f0b8d6a8254835884758179df40923cb377564c0fc4c7dc2f7f6` |

## Binary and build evidence

- MacBook staging (ignored from Git): `.flick-nix-candidate/flick-logging-x86_64`.
- Full build log (ignored from Git): `.flick-nix-candidate/build-release.log` (2,203 lines; SHA-256 `f78bb82b204d927b508b1b033db786addd343a119919202c94376df95ae85d6b`).
- User-home staging on Lenovo: **`/home/alex/lenovo-mvp/builds/flick-logging-x86_64`**.
- SHA-256 on the tablet **matched** the Mac artifact.
- `flick --help` succeeded in the Mac-hosted x86_64 Linux container; the staged binary's `--help` also succeeded **on the real tablet** without starting another compositor.
- Compared direct Nix runtime references for the unwrapped build against the existing tablet unwrapped Flick package: **the nine direct runtime references were identical**.
- This is **not** an activated NixOS generation or a validated graphical session. The binary still requires a controlled temporary runtime test with a planned rollback before any performance claims.

## Build caveats and security

The first Rosetta build attempt failed before compilation because a seccomp BPF program could not load. The second attempt progressed to Flick but the context-heavy logging patch was rejected by GNU patch at one hunk. The corrected patch uses 30 zero-context, narrowly scoped substitutions; all 30 applied during the **successful third build**. No source changes unrelated to the logging level were included.

During final Rust code generation, the VM approached its 6 GiB RAM limit. A **temporary 3 GiB VM-local swap file** was provisioned; roughly 380 MiB was used. This changed neither tablet swap nor tablet Nix settings. `filter-syscalls=false` is deliberately scoped to a disposable build container with the source tree mounted read-only; **do not set it on the tablet**.

## Next controlled test gate

Keep the current healthy `flick.service` and Rust/Slint dashboard running until a local recovery plan is ready. A live compositor restart disrupts the user's GUI session and may affect remote recovery. Before a temporary test: retain the known-good binary and generation, arrange physical access and a timed recovery method, then measure Flick CPU, log bytes/sec, touchscreen, QML lock/unlock/keyboard and i915 stability. Only if the logging-only candidate passes should the separate experimental QML/Slint rasterisation patch be compiled and tested independently.
