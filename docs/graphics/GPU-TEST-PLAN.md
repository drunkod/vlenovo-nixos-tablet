# Graphics development test plan

The target is the Lenovo Miix 2 10 / Bay Trail GPU `8086:0f31`.
The known-good implementation is Linux i915 + Mesa Crocus.

## Phase 0 — preserve a known-good state

1. Record the current NixOS system/profile/booted generations.
2. Capture a full GPU baseline with `tools/collect-gpu-state`.
3. Copy the raw i915 VBT and ACPI tables into the capture directory.
4. Keep the current permanent generation bootable in GRUB.
5. Do not change kernel, Mesa and compositor simultaneously.

A test is considered recoverable only if SSH still works or the previous
NixOS generation can be selected at boot.

## Phase 1 — define the symptom

For every suspected graphics issue, write down:

- exact action that reproduces it;
- expected and actual behaviour;
- whether it reproduces after a clean boot;
- whether it affects only the internal DSI panel;
- whether it is Wayland/Sway-specific;
- whether it is OpenGL-specific;
- whether suspend/resume is required;
- whether a GPU reset, underrun, error or warning appears.

## Phase 2 — classify the subsystem

Use this decision tree:

- Panel mode, blanking, backlight, rotation, suspend display failure:
  inspect i915 DRM/KMS, VBT and Valleyview DSI.
- GPU hang/reset, submission or clocking problem:
  inspect i915 GT/GEM/RPS/runtime-PM.
- OpenGL misrendering or crash with KMS otherwise healthy:
  inspect Mesa Crocus.
- Video decode performance:
  inspect VA-API/media separately; do not treat it as a Crocus bug.
- Desktop jank with healthy GPU:
  measure Sway/SXMO/CPU/RAM before changing the graphics driver.

## Phase 3 — upstream-first experiment

1. Check whether the issue is already fixed in newer Linux or Mesa.
2. If fixed, identify the smallest responsible commit.
3. Backport that commit before writing new device-specific code.
4. If it is a regression, identify good and bad revisions and bisect.
5. Keep the baseline and changed captures for comparison.

## Phase 4 — device-specific fix

Only after a reproducible device-specific defect is proven:

1. Inspect the Miix VBT and ACPI description.
2. Compare the failing path with existing Valleyview/Lenovo quirks.
3. Prefer a narrowly matched PCI subsystem or DMI quirk.
4. Avoid global Valleyview behaviour changes unless the bug is generic.
5. Document why Lenovo `17aa:3901` needs the exception.
6. Test boot, display, brightness, touch, suspend/resume, HDMI if available,
   GPU load, idle power, Meta key and SXMO gestures.

## Kernel acceptance gate

Before a patched kernel becomes permanent:

- SSH works after activation.
- DSI-1 is connected at 1920x1200@60.
- No new i915 errors or GPU resets.
- No persistent FIFO underruns.
- `glxinfo -B` still reports Crocus and direct rendering.
- Runtime PM reaches idle.
- GPU frequency scales between idle and load.
- Suspend/resume succeeds repeatedly.
- SXMO widgets and input still work.
- `systemctl --failed` is empty or unchanged.
- A previous NixOS generation remains bootable.

## Userspace/Mesa acceptance gate

For a Crocus experiment, run the application against a local Mesa build first.
Do not replace the system Mesa until the test case is demonstrably fixed.

## Evidence to save for every experiment

Save a before/after capture containing:

- kernel and NixOS generation;
- PCI/DMI identity;
- DRM connector/mode state;
- raw VBT;
- ACPI dump when relevant;
- i915 debugfs state;
- kernel DRM/i915 journal;
- Mesa renderer/version;
- GPU frequencies/runtime PM;
- exact patch/commit IDs;
- command used to reproduce the issue;
- result and rollback procedure.

Do not use synthetic benchmarks alone as proof of correctness. The tablet's
DSI panel, power sequencing and resume behaviour are as important as raw FPS.
