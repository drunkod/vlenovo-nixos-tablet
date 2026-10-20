# Lenovo Miix 2 10 graphics development / porting plan

## Decision

Do **not** try to convert Lenovo's old Windows WDDM binaries into a Linux
driver. This tablet already has a native accelerated Linux stack:

- Intel Atom Z3745 / Bay Trail / Valleyview, PCI `8086:0f31`;
- Lenovo subsystem `17aa:3901`;
- kernel DRM/KMS driver: `i915`;
- userspace OpenGL driver: Mesa Crocus;
- internal panel: MIPI-DSI, 1920x1200@60;
- fixed-function media: Intel i965 VA-API works when packaged on NixOS.

The Windows packages are reference material for hardware IDs, policy,
firmware behaviour and comparison testing. They are not source code that can
be recompiled as `i915.ko`.

The engineering goal is therefore:

> reproduce a concrete graphics defect, identify whether it belongs to i915,
> Crocus, VA-API or Sway, then backport or implement the smallest justified fix.

See `WINDOWS-REFERENCE.md`, `VBT.md`, `UPSTREAM.md` and
`MEDIA-ACCELERATION.md` for the evidence behind this decision.

## Safety baseline
Preserve the current known-good boot profile before every kernel experiment.
The tablet may run a different `nixos-rebuild test` generation temporarily;
that is intentional. Never make a graphics experiment the boot default before
it has passed the acceptance checks below.

Capture a baseline on the tablet, as the graphical-session user:

```sh
nix develop .#graphics
tools/collect-gpu-state debug/gpu-captures
```

The collector uses `sudo -n` for privileged debugfs/ACPI reads. Running the
whole collector as root changes the session UID/environment and can miss the
user's Sway socket or Xwayland authentication. Check captured command output
for failures; collector completion alone does not prove every probe succeeded.

Keep the raw VBT, ACPI tables, DRM connector state, i915 debugfs state,
kernel log, OpenGL renderer and VA-API output. The known VBT SHA256 is:

```text
ac43644603f1e519ce83c594e1ef75f8c779533fdd51864d293876893c519312
```

The live healthy reference has reset count 0, `ERROR=0x00000000`, runtime PM
enabled, GPU idle at rest, 200 MHz minimum, 578 MHz RPe and 778 MHz maximum.

## Phase 1 — define a reproducible symptom

Do not patch based on the idea that the Windows driver may be "better".
Choose a measurable failure and write exact reproduction steps.
Classify it before touching code:

| Symptom | First subsystem to investigate |
|---|---|
| black panel / bad resume / brightness | i915 display, VBT, Valleyview DSI |
| GPU reset or hang | i915 GT/GEM plus submitted workload |
| OpenGL misrender with clean kernel log | Mesa Crocus |
| slow H.264/MPEG-2/VC-1/JPEG playback | VA-API / player zero-copy path |
| tearing or desktop animation latency | Sway/wlroots/KMS scheduling |
| high idle power | runtime PM/RPS/display state, then compositor |
| HDMI/output problem | i915 KMS connector/output path |

For every reproduction save `dmesg`, `i915_error_state`,
`i915_gpu_info`, `i915_frequency_info`, `i915_runtime_pm_status`,
`i915_display_info`, connector state, and the exact workload.

For a rendering problem, first reproduce with software rendering and then with
Crocus. Capture an apitrace where practical. Mesa's debugging guide explicitly
recommends separating application, userspace-driver and kernel failures before
changing code.

## Phase 2 — test newer upstream before writing a fix

First test whether a newer kernel or Mesa already fixes the exact symptom.
Do not interpret every commit touching `vlv_dsi.c` as a Valleyview fix:
the file also contains Broxton/Cherryview-era paths.

Current screening already rejects several tempting candidates:
- `c464ce6af332...` fixes `BXT_MIPI_TRANS_VTOTAL`; it is Broxton-specific,
  not a Bay Trail/Valleyview timing fix.
- `e778689390c7...` extends the VLV v1/v2 MIPI-sequence fixup, but the Miix
  VBT contains block 52 and no block 53 MIPI sequence table, so it is not an
  evidence-based backport for this machine.
- `ca677505e477...` changes Ice Lake/newer DSI timing, not Valleyview.
- historical Valleyview/Cherryview PSR code was for DP/eDP and was removed;
  the Miix internal connector is DSI-1, so restoring VLV PSR is not a target.
- `77ba0b856225...` converted the Valleyview DSI path to the newer
  `intel_display` structure. The later `7da6c155a67d...` NULL-dereference
  fix repairs a regression introduced by that conversion; it is important
  when testing affected newer kernels, but it is not a missing fix for 6.12.
- recent VLV IOSF-sideband/display refactors are not performance fixes by
  themselves and should not be backported merely because they touch VLV code.

Existing upstream Lenovo Yoga Tablet 2/3 DSI quirks are useful *patterns*:
they show that a DMI-specific fix is appropriate when firmware supplies a
provably wrong bus, size or sequence. They are not fixes for the Miix unless
the same defect is reproduced here.

If an upstream kernel fixes a real Miix symptom, locate the exact fixing commit
with comparison or `git bisect`, then backport that commit rather than
inventing an alternative.

## Phase 3 — targeted test tooling

Use IGT GPU Tools for low-level DRM/KMS/i915 testing. List subtests first and
run only relevant subtests; many IGT tests require root and no compositor.

```sh
TEST --list-subtests
sudo TEST --run-subtest NAME
```
Start with safe read-only or narrowly scoped tests. Do not launch the entire
IGT suite blindly on the only working tablet; some tests deliberately exercise
reset, suspend, modesetting and failure paths.

For media performance use:

```sh
nix develop .#graphics
tools/benchmark-vaapi INPUT.mp4
```

The current 1080p30 H.264 benchmark already showed direct VA-API decode at
about 16x realtime versus about 5.5x in software, while using roughly 86% fewer
CPU-seconds. Keep decoded frames in GPU/DMABUF paths; downloading every frame
to CPU memory destroys much of the benefit.

## Phase 4A — kernel/display fix

A DSI, backlight, suspend/resume or KMS issue belongs in the kernel path,
primarily:

```text
drivers/gpu/drm/i915/display/vlv_dsi.c
drivers/gpu/drm/i915/display/vlv_dsi_pll.c
drivers/gpu/drm/i915/display/intel_dsi_vbt.c
drivers/gpu/drm/i915/display/intel_bios.c
drivers/gpu/drm/i915/display/intel_quirks.c
```

Use Intel's public Bay Trail PRM to correlate registers, timings and command
semantics. Prefer firmware/VBT evidence over reverse engineering the Windows
binary.
If the defect is Lenovo-board-specific, key the smallest fix to sufficiently
specific DMI data or to PCI device/subsystem IDs only when that is the correct
upstream matching mechanism. Never add a quirk without a before/after
reproduction proving what firmware value or sequence is wrong.

For a small 6.12 backport, keep the patch under `patches/i915/` and apply it
with a NixOS kernel patch. For development against a different kernel tree,
use a custom kernel with `pkgs.linuxPackagesFor`.

For a **kernel** experiment, `nixos-rebuild test` cannot replace the kernel
that is already running. Use this sequence instead:

```text
build -> retain known-good generation and arrange local recovery
      -> boot (changes boot default) -> reboot into candidate
      -> verify uname/kernel package and booted generation
      -> fresh SSH -> display -> Meta key/touch/gestures
      -> targeted IGT/KMS -> suspend/resume -> stress
      -> retain candidate or explicitly restore known-good boot default
```

`nixos-rebuild boot` is not a one-shot boot: it makes the candidate the next
boot default before acceptance testing. Another reboot does not automatically
undo it. If preserving the default throughout is required, use a separately
verified bootloader-specific one-shot/manual selection workflow instead.
Do not garbage-collect the known-good generation during the experiment.

For userspace-only changes such as Mesa or VA-API, `nixos-rebuild test` is
appropriate: it changes the running configuration without changing the boot
default. Restart the graphical session/application so it loads the new
libraries. Reboot still returns to the known-good boot generation.

## Phase 4B — Mesa/Crocus fix

For an OpenGL rendering bug with a clean i915 state, work in Mesa first.
Build Mesa in a separate Meson build directory and run the reproducer inside
Mesa's development environment rather than replacing system Mesa immediately:

```sh
meson setup builddir
meson compile -C builddir
meson devenv -C builddir glxinfo
```
Use apitrace or another minimal reproducer, identify a known-good and bad Mesa
revision, and bisect. A local Mesa test is lower risk than a custom kernel and
should be preferred whenever the fault is clearly userspace rendering.

Current research has not identified a Bay Trail-only Crocus fix that
justifies replacing Mesa 25.0.7 without a symptom. One newer shared fix is
worth a controlled A/B test: `686266d2f1aa...` (`crocus: Fix shader
precompilation on Gen6 and higher`) applies to Gen7 too. It fixes fragment
shaders being compiled twice and duplicated in caches, so it may reduce
application startup/draw-time stutter. Test it as a Mesa experiment; it is not
hardware-enablement code and is not a reason to rewrite i915.

Its inclusion is documented in Mesa 26.0.6 and 26.1.0 release notes. This
establishes availability, not a measured Sway benefit. A newer-version A/B
test measures many Mesa changes; isolating this fix requires otherwise
identical builds with/without the patch. Separate cold and warm shader caches,
restart the process under test, and verify its loaded libraries. Testing one
application with `meson devenv` does not update an already-running compositor.
See `RESEARCH-REVIEW.md` for evidence, caveats and the controlled test design.

## Phase 5 — upstream a real fix

Once a fix is demonstrated:

1. reproduce on a suitable current upstream kernel/Mesa as well as the NixOS
   base;
2. keep one logical problem per patch;
3. quantify performance claims and document before/after behaviour;
4. run the relevant IGT tests and the tablet acceptance tests;
5. for kernel patches run `scripts/checkpatch.pl`;
6. use `scripts/get_maintainer.pl` on the patch paths;
7. include dmesg/reproduction details and a `Fixes:` tag when applicable;
8. submit through the DRM/i915 review process and only then maintain a stable
   backport where needed.

## Learning order

Read the kernel DRM Introduction first, then KMS concepts, then the actual
Valleyview i915 files above. Next study Intel Bay Trail PRM volumes 3
(GPU overview), 6 (command stream), 7 (3D/media/GPGPU) and 10 (display).
For userspace work, read the Gallium introduction, Crocus source, Mesa
debugging guide and IGT documentation.
Primary references are maintained in `REFERENCES.md`. Particularly useful
starting points are:

- https://docs.kernel.org/gpu/introduction.html
- https://docs.kernel.org/gpu/
- https://docs.kernel.org/process/submitting-patches.html
- https://docs.mesa3d.org/install.html
- https://docs.mesa3d.org/graphics-debugging/debugging-misrenderings-crashes.html
- https://docs.mesa3d.org/gallium/intro.html
- https://drm.pages.freedesktop.org/igt-gpu-tools/
- https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/bay-trail.html
- https://nixos.org/manual/nixos/stable/

## Immediate next experiments

The highest-value next step is **not** to write an i915 quirk. It is to keep
the current VA-API userspace improvement, capture one clean post-change GPU
baseline, and then choose one actual graphics symptom to investigate.

If no graphics symptom exists, a controlled newer-kernel A/B test is still
useful as a compatibility experiment, but success alone is not a reason to
backport arbitrary i915 changes. Compare connector state, VBT hash, runtime
PM, reset/error counts, suspend/resume, brightness, video decode, Sway
responsiveness and power/CPU behaviour against the 6.12 baseline.

The old Windows driver remains valuable for differential testing: compare
panel power sequencing, brightness behaviour, display timing and media
capabilities where measurable. Treat registry policy names as clues, not as
Linux module parameters.
