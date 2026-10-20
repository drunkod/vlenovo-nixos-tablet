# MacBook x86_64 Linux build environment — 2026-10-21

## Why this builder
The Lenovo tablet uses x86_64 Linux, but the MacBook Air runs aarch64 Darwin. A native macOS compilation cannot be copied to the tablet. The MacBook already had Homebrew Colima 0.10.3 and Lima installed. No Linux VM was active. A separate **Colima VZ virtual machine with Rosetta x86_64 emulation** was successfully started and independently tested with an Alpine amd64 container (`uname -m` returned `x86_64`). The pinned `nixos/nix:2.28.4` amd64 image also started successfully and reported Nix 2.28.4.

### VM and container setup
On the MacBook, using a unique VM profile so no existing Docker instance is overwritten:

```bash
colima start --profile vlenovo-flick-build \
  --arch aarch64 --vm-type vz --vz-rosetta \
  --cpus 4 --memory 6 --disk 26 --root-disk 20 \
  --runtime docker \
  --mount /Users/test/Documents/Work/vlenovo-nixos-tablet:w
```

This VM has 4 vCPUs, 6 GiB RAM, a 20 GiB Linux root filesystem and a 26 GiB Docker data disk (thin-provisioned; watch actual Mac free space). It shares the Mac Git checkout so the Nix flake is read-only inside the Docker container.

```bash
W=/Users/test/Documents/Work/vlenovo-nixos-tablet/.local/worktrees/vlenovo-flick-gpu-opt
docker --context colima-vlenovo-flick-build run -d \
  --name vlenovo-flick-nixbuild --platform linux/amd64 \
  --cpus=4 --memory=5g \
  --mount "type=bind,source=$W/experiments/flick-build,target=/work,readonly" \
  -w /work -e NIX_REMOTE=local \
  nixos/nix:2.28.4 sh -c 'sleep 86400'
```

The container was created successfully, with `/work/flake.nix` and `/work/pkgs/flick/default.nix` visible, a real x86_64 Linux Nix userspace, and ~24 GiB initially available in its overlay filesystem.

### Build commands and evidence

```bash
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
  --option sandbox false eval --raw \
  'path:/work#packages.x86_64-linux.flick.name'
```

**Result:** `flick-unstable-2026-01-04`; this checks evaluation, not compilation.

For the actual Rust package, avoiding the unrelated QML/Qt5 assets:

```bash
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  nix --extra-experimental-features 'nix-command flakes' \
  --option sandbox false --option max-jobs 2 --option cores 2 \
  build 'path:/work#packages.x86_64-linux.flick.unwrapped' \
  --no-link --print-out-paths -L
```

An asynchronous execution was started with output redirected to `/tmp/vlenovo-flick-build.log` inside the container; the exit status is saved as `/tmp/vlenovo-flick-build.rc` when the command exits. Inspect with:

```bash
docker --context colima-vlenovo-flick-build exec vlenovo-flick-nixbuild \
  sh -c 'if test -f /tmp/vlenovo-flick-build.rc; then cat /tmp/vlenovo-flick-build.rc; else echo RUNNING; fi; tail -20 /tmp/vlenovo-flick-build.log; df -h /nix/store'
```

**Do not claim a built candidate until the exit status is zero and the Nix output path is verified.** Building inside the container never activates/restarts the tablet's Flick service. For deployment, preserve Nix store closures and check ABI/runtime dependencies; copying a single executable without its matching libraries is insufficient.

To stop the VM when no build is running, use `colima stop -p vlenovo-flick-build`. Stopping the VM pauses/disconnects container execution; do not stop it while a build is still in progress.

The original tablet system and native touchscreen dashboard remain running. The performance target is unchanged: reduce per-render INFO log overhead first, then profile full-screen Slint pixel-buffer redraws before implementing a damage-aware compositor change.
