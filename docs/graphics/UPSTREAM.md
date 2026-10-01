# Upstream i915 / Mesa research notes

This is a screening log for upstream changes that might matter to the
Lenovo Miix 2 10 (Bay Trail / Valleyview, PCI 8086:0f31).

## Existing upstream support

Current Linux identifies `0x0f31` through `INTEL_VLV_IDS` and maps the
device to the Valleyview i915 platform implementation.

The kernel has dedicated Valleyview display code, including:

- `drivers/gpu/drm/i915/display/vlv_dsi.c`;
- `vlv_dsi_pll.c`;
- `intel_dsi_vbt.c`;
- VBT parsing in `intel_bios.c`;
- Valleyview-specific backlight, vblank and power workarounds.

Mesa selects Crocus for the tablet and provides accelerated OpenGL.
A replacement kernel/display driver is therefore not the starting point.

## Device-quirk precedent already in Linux 6.12

The v6.12 `vlv_dsi.c` contains a DMI quirk framework for Bay Trail /
Cherry Trail tablets.

Relevant examples include:

- ASUS TF103C: fixes a firmware-provided mode whose vtotal is wrong.
- Lenovo Yoga Tablet 2 830/1050: corrects a MIPI I2C bus mismatch and
  bogus physical panel size.
- Lenovo Yoga Tab 3 Pro X90F: corrects I2C adapter selection and supplies
  a missing backlight-off sequence.

These establish the correct upstream pattern: prove the firmware defect,
then add the smallest DMI-specific fix rather than changing all Valleyview
systems.

The Miix DMI strings do not match those existing Lenovo quirks.

An exact-name search of the upstream Linux commit history finds several
Miix 2 10 fixes in ASoC/RT5670 audio and i2c-hid/sensor handling, but no
model-named i915 graphics quirk. This does not prove that no generic
Valleyview graphics fix ever affected the device, but it is further evidence
against starting with a Miix-specific graphics patch without a reproduced bug.

There is useful historical evidence from the closely related Lenovo Miix 2 8.
In 2017 a tester reported that the upstream Valleyview DSI clock-gating fix
`bb98e72adaf9`/`721d484563e1` fixed intermittent i915 panel initialization on
that Bay Trail tablet. The fix preserves `DPOUNIT_CLOCK_GATE_DISABLE` while a
DSI pipe is active. It has been upstream for many years and is already part of
modern kernels, so it is evidence that i915 is the right driver family, not a
patch we need to port to Linux 6.12.

## Post-6.12 Valleyview/DSI fixes screened

### Late-2024 DSI/VBT cleanups

Commits `95601c60b1be` and `252cea7f0fb4` move the existing Valleyview DSI
minimum-CDCLK rule into `vlv_dsi.c` and simplify it. They preserve the same
320 MHz minimum already present in the older code for Valleyview DSI panels,
so they are structural cleanups rather than a performance fix for this tablet.

Commit `ef0430f5d3ab` replaces an accidental register-format/VBT-format
coupling with an explicit VBT-to-MIPI pixel-format conversion. The Miix VBT
reports RGB888, which maps to RGB888 in both the old and new code, so there is
no evidence this changes behaviour on this machine.

### 2025 MIPI v1/v2 sequence fixup

Commit `e778689390c7` extends `vlv_fixup_mipi_sequences()` to version-2
MIPI sequence tables. It fixes tablets whose INIT_OTP sequence contains
reset deassertion while a DEASSERT_RESET sequence is missing.

Status for Miix 2 10: **not an obvious candidate**. The decoded Miix VBT
contains MIPI configuration block 52 but no MIPI sequence block 53.

### 2025 vlv_dphy_param_init NULL-deref fix

Commit `7da6c155a67d` fixes a NULL dereference introduced by the newer
`struct intel_display` refactor.

Status for our 6.12 base: **not applicable as a backport**. The regression
was introduced after the code in our kernel.

### 2025 separate DSI clock/data prepare timing

Commit `ca677505e477` makes clock and data lane timing independent to
match Windows behaviour.

Status for Miix: **not applicable**. The patch changes `icl_dsi.c`
(Ice Lake/newer DSI), not Valleyview `vlv_dsi.c`.

### 2026 LP-clock / BLLP changes

The 2026 DSI patches which honor VBT LP-clock-during-LPM and blanking packet
settings are guarded for newer display generations (TGL/ADL-era paths).

Status for Miix: **not applicable**.

### 2026 PREEMPT_RT VLV DSI/vblank work

A 2026 PREEMPT_RT series includes Valleyview DSI vblank-workaround changes.
It is aimed at making i915 work correctly with PREEMPT_RT and changes
locking/IRQ behaviour.

Status for this tablet: **do not backport without a matching symptom**.
The current NixOS kernel is not being developed as a PREEMPT_RT target.

## Current conclusion

No screened post-6.12 commit provides a justified general-purpose
performance patch for this Miix.

Before any backport, we need one of:

1. a reproducible DSI/backlight/suspend defect;
2. a reproducible GPU hang/reset;
3. a rendering bug attributable to Crocus;
4. a measurable performance regression with a known-good comparison.

If a newer upstream kernel fixes such a symptom, identify the responsible
commit by comparison/bisection and backport only that change.

## Useful upstream files for future work

Kernel:

- `include/drm/intel/pciids.h`
- `drivers/gpu/drm/i915/i915_pci.c`
- `drivers/gpu/drm/i915/display/vlv_dsi.c`
- `drivers/gpu/drm/i915/display/vlv_dsi_pll.c`
- `drivers/gpu/drm/i915/display/intel_dsi_vbt.c`
- `drivers/gpu/drm/i915/display/intel_bios.c`
- `drivers/gpu/drm/i915/display/intel_quirks.c`

Userspace:

- Mesa Crocus under the Intel Gallium driver sources.
- IGT GPU Tools for DRM/KMS/i915 tests and Intel diagnostics.
