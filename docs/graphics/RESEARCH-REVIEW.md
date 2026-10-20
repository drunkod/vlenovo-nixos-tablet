# Graphics research review — 2026-10-02

## Scope and verdict

Reviewed the two supplied research/conversation attachments and the repository's
baseline, test plan, upstream screening, media notes, porting plan and capture/
benchmark scripts. Reconnected over key-only SSH for read-only probes. No
configuration was activated, no session restarted, and no kernel or driver was
changed. This is an evidence review, not a claimed 30-minute timed experiment.

CodeGraph was attempted first, as requested. This checkout has no `.codegraph`
index, so it could not search it; file tools were used instead. No index was
created. Exa completed a multi-source research run. Tavily's pro research call
timed out; subsequent Tavily search/extraction worked. Current MCP availability
must not be inferred from old authentication/credit failures in the attachments.

**The central conclusion is sound:** improve existing i915/Crocus/media support,
not port Windows WDDM binaries. A missing Linux GPU driver is not demonstrated.
The Crocus precompilation fix is a valid candidate, not a proven cure for Sway
latency. The earlier SXMO service-loop performance findings must remain separate
from GPU performance claims.

## Current tablet evidence

Executed SSH probes used `BatchMode=yes`, `ConnectTimeout=8`,
`IdentitiesOnly=yes` and `StrictHostKeyChecking=yes` with the existing Mac key.

| Probe | Observed result |
|---|---|
| Host / kernel | `vlenovo`, Linux `6.12.36` |
| Sysfs PCI / subsystem | `8086:0f31` / `17aa:3901` |
| Bound driver | `/sys/bus/pci/drivers/i915` |
| Connector | DSI-1 connected, advertised mode `1920x1200` |
| Firmware platform size | 32-bit UEFI |
| GPU state | VALLEYVIEW, graphics/media generation 7, reset count 0, `ERROR=0x00000000` |
| Error-state file | Empty in this probe |
| Runtime PM | Enabled, GPU idle, usage count 0 |
| Clocks | Actual 200 MHz; min 200, RPe 578, max 778 MHz |
| Failed systemd units | 0 |
| Memory PSI | Both `some` and `full` averages 0 |
| VA driver file | `i965_drv_video.so` points to `intel-vaapi-driver-2.4.1-unstable-2024-10-29` |
| Sway | `1.10.1`, PID 554921 at inspection |
| Sway loaded userspace | Mesa 25.0.7 EGL, Gallium and DRI GBM backend; libgbm frontend 25.0.1 |
| Raw VBT SHA256 | `ac43644603f1e519ce83c594e1ef75f8c779533fdd51864d293876893c519312` |

The different libgbm frontend/backend version labels are an observation, not
proof of an ABI fault. Record them as experimental controls; do not change
packages solely to make version strings match.

Generations observed:

```text
current: /nix/store/d4c7kcl2qrn75bmwkjpy10jpb05cilhv-nixos-system-vlenovo-25.05.20250708.88983d4
profile: /nix/store/4nccr8wjih2g6dsjlxcyi5d7v7354m2n-nixos-system-vlenovo-25.05.20250708.88983d4
booted:  /nix/store/hw4s0arbrf55mavrjk9k48zyackzhf9p-nixos-system-vlenovo-25.05.20250708.88983d4
```

These three paths have distinct meanings. The profile is the persistent system
selection; `booted` records the generation which started this boot, not the next
boot choice. The current VA-API runtime remains different from the profile.

`lspci` was unavailable, so IDs were independently read from sysfs. The numeric
`/sys/kernel/debug/dri/0` path was absent; the PCI-named debugfs directory worked.
Reading Sway maps required `sudo -n`. These probe failures were resolved without
installing packages. This pass did not rerun `vainfo`, decode benchmarks, OpenGL
feature queries, refresh-rate queries, physical input tests or suspend/resume.
Driver-file presence alone does not prove hardware decoding in a player.

## Findings and corrections

### 1. Kernel-test instructions needed correction

`GPU-BASELINE.md` previously required `nixos-rebuild test` for all kernel
experiments. That activation cannot change the executing kernel. Build the
candidate, retain the old generation, arrange local GRUB recovery, install a
boot candidate, reboot, then verify the booted generation and kernel package.

**`nixos-rebuild boot` changes the boot default.** It is not a one-shot experiment
and reboot alone will not roll it back. Userspace `test` activation, by contrast,
leaves the boot default unchanged. The baseline, test plan and porting plan now
state this explicitly. An SSH rollback timer is insufficient protection against
a candidate kernel that cannot boot or bring up networking.

### 2. Crocus fix verified; performance benefit unmeasured

Commit `686266d2f1aae3027fd039386c166ce3fadfce7f` is titled
“crocus: Fix shader precompilation on Gen6 and higher”. The commit describes
incorrect predicted fragment-shader keys, resulting in recompilation at draw
time and duplicate memory/disk-cache entries. Gen7 is within its stated scope.
It corrects existing runtime precompilation; it does not precompile Sway during
a Nix build or promise all state-dependent shader variants are available.

The author date is June 2025, but the committer date is April 22, 2026. Do not
use the author date to infer inclusion in a 2025 Mesa release. Official release
notes list the fix in Mesa 26.0.6 and 26.1.0. They do not establish a measured
benefit on this Miix, nor make those historical releases today's preferred
maintained version. Verify the chosen package's exact source/patches.

A local `meson devenv ... glxinfo` verifies that application, not the running
compositor. The read-only `/proc` inspection in this review establishes that
Sway currently loaded Mesa 25.0.7 EGL/Gallium. A compositor experiment requires
restarting Sway under the candidate stack and rechecking loaded libraries and
renderer logs. Do not infer the exact renderer solely from a shell GLX probe.

### 3. Media acceleration is useful but separate

Bay Trail uses legacy `intel-vaapi-driver` / VA backend `i965`. The newer
`intel-media-driver` / `iHD` platform list does not include Bay Trail. This VA
`i965` name is not Mesa's old classic OpenGL i965 driver and is not Crocus.

The repository's approximately 2.9x decode throughput and 86% lower CPU-time
results are historical **synthetic H.264 decode-only** measurements. They do not
prove the same improvement in browser playback, battery life, or compositor
frame pacing. Validate the actual player's backend, video-engine activity,
dropped frames and frame-transfer path. Codec/profile/entrypoint support must
come from `vainfo` and successful workload tests, not the package name.

Intel has discontinued upstream maintenance of `intel-vaapi-driver`, including
security fixes. It remains the compatible legacy backend; the generic advice
to move to iHD does not provide Bay Trail support. Record this maintenance risk
and assess distro patches/application exposure rather than describing it as a
fully maintained modern replacement.

### 4. PSR and device quirks are not justified optimizations

The existing upstream screening correctly rejects restoring historical VLV/CHV
PSR for this DSI panel. Upstream removed that implementation with
`ce3508fd2a778e9366ab638f4e1dbe6dab874c5b`. Setting `i915.enable_psr=1` cannot
restore removed code. A generic Windows INF feature bit is not panel-specific
proof. Existing Yoga DSI quirks establish a development pattern, not a defect
in the Miix VBT. No new Miix quirk is justified by this review.

### 5. Capture and benchmark caveats

Run `tools/collect-gpu-state` as the session user in the graphics dev shell. It
already elevates privileged reads internally. Elevating the whole script can
lose the user's Sway socket/authentication and shell PATH. The porting plan's
command is corrected accordingly.

The collector deliberately tolerates probe failures. Inspect each output;
“capture complete” does not mean every test succeeded. Some probes are bounded,
but `glxinfo`, direct debugfs reads and ACPI operations are not all individually
time-limited. The benchmark has no internal FFmpeg timeout either: use a known,
bounded clip and an outer timeout for unattended runs. No script changes were
made in this review.

The benchmark runs software trials before VA-API trials and displays truncated
logs. For stronger performance evidence, preserve full logs, alternate order,
record thermals/power, and compare identical input hashes. An initialization
success or a null-output throughput test is not an end-to-end playback test.

## Controlled next experiment

1. Choose a repeatable real symptom: first application draw, workspace animation,
   keyboard-open latency, or video playback. Save reproduction steps and the
   unchanged baseline before selecting a patch.
2. Start with one application and isolated Mesa builds. Keep kernel, Sway,
   display mode/scale, power policy and workload fixed. Do not upgrade the whole
   NixOS stack just to test Crocus.
3. Distinguish **upgrade comparison** (Mesa 25.0.7 vs a chosen newer release)
   from **patch attribution** (same source/build options with and without this
   fix). Only the latter isolates the precompilation change; first verify that
   applying/reverting it is valid on the chosen source.
4. Use separate dedicated `MESA_SHADER_CACHE_DIR` directories. Test enabled
   cold caches, then identically primed warm caches. Do not delete the user's
   normal cache. Cache-disabled runs are a separate condition.
5. Alternate A/B order for at least five trials per condition. Record first-frame
   latency, frame-time distribution/p95/p99, missed presentation deadlines,
   CPU time, memory, shader compilation/key misses, GPU busy/frequency and PSI.
   Separate instrumented mechanism checks from minimally instrumented timing
   runs. A FPS average or glxgears number cannot establish compositor latency.
6. Only if compositor testing is warranted, use temporary userspace activation
   with recovery access, restart the session and verify loaded EGL/Gallium/GBM
   paths. Check Meta/OSK, gestures, widgets, display correctness and fresh SSH.
7. Accept a patch only for a repeatable benefit beyond run-to-run variability
   with no functional regression. A null benefit is a valid result. Do not make
   it permanent automatically.
8. Test a maintained kernel separately if a display/resume or maintenance need
   exists. Do not mix kernel changes into the Mesa experiment. Low-level IGT
   modesetting/reset/suspend tests need explicit disruptive-test planning;
   listing subtests does not prove they are safe under the compositor.

## Primary sources and learning sequence

- [DRM introduction](https://docs.kernel.org/gpu/introduction.html): architecture
  and tiny DRM drivers as teaching examples, not replacements for i915.
- [i915 documentation](https://docs.kernel.org/gpu/i915.html): display/VBT and
  driver-specific context.
- [Intel Bay Trail PRM](https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/bay-trail.html): hardware reference.
- [Mesa local-build workflow](https://docs.mesa3d.org/install.html): Meson setup,
  compile and application-scoped `devenv`; Nix build dependencies still required.
- [Exact Crocus commit](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/686266d2f1aae3027fd039386c166ce3fadfce7f)
  and [diff](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/686266d2f1aae3027fd039386c166ce3fadfce7f%5E%21/).
- [Mesa 26.0.6](https://docs.mesa3d.org/relnotes/26.0.6.html) and
  [26.1.0](https://docs.mesa3d.org/relnotes/26.1.0.html): release inclusion.
- [Mesa environment variables](https://docs.mesa3d.org/envvars.html): cache controls.
- [Legacy VA driver](https://github.com/intel/intel-vaapi-driver) and
  [PCI IDs](https://github.com/intel/intel-vaapi-driver/blob/master/src/i965_pciids.h):
  Bay Trail support and maintenance status.
- [Newer media-driver support](https://github.com/intel/media-driver/blob/master/README.md):
  iHD hardware scope.
- [VLV/CHV PSR removal](https://github.com/torvalds/linux/commit/ce3508fd2a778e9366ab638f4e1dbe6dab874c5b).
- [IGT running tests](https://drm.pages.freedesktop.org/igt-gpu-tools/running_tests/):
  targeted test selection; inspect the actual test implementation before use.
- [NixOS manual](https://nixos.org/manual/nixos/stable/): build/test/boot semantics.
- [Submitting patches](https://docs.kernel.org/process/submitting-patches.html):
  small justified patches, checkpatch and maintainer discovery.

No Windows binary port, BIOS flash, speculative kernel parameter change,
package upgrade, commit or push was performed.
