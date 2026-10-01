# Miix 2 10 VBT and ACPI notes

This file documents firmware data extracted from the Lenovo Miix 2 10
before any graphics-driver patching.

## Raw VBT

The running i915 driver exposes the VBT through debugfs. The baseline dump is:

- Signature: `$VBT VALLEYVIEW`
- VBT version: 1.0 (`0x0064`)
- BDB version: 178
- Raw VBT SHA256:
  `ac43644603f1e519ce83c594e1ef75f8c779533fdd51864d293876893c519312`

The decoded child-device record describes LFP1 as:

- internal connector;
- MIPI output;
- DVO port MIPI-A;
- integrated encoder.

No BDB block 53 (MIPI sequence block) is present in this VBT.
BDB block 52 (MIPI configuration) is present.

## Panel timing

The VBT's preferred panel timing is:

- 1920x1200;
- pixel clock 148.350 MHz;
- hsync 1960..2000, htotal 2040;
- vsync 1204..1208, vtotal 1212;
- 60 Hz as exposed by DRM.

The live i915 connector reports physical dimensions 216x135 mm.

The AUO B101UAN01.7 panel documented for the Miix 2 10 is an unusually strong
cross-check. Its public specification gives the same typical mode: 148.35 MHz
pixel clock, 2040 total horizontal pixels, 1212 total vertical lines, and
1920x1200 at 60 Hz. AMD's current MIPI-DSI interoperability test matrix also
uses B101UAN01.7 at 1920x1200@60 with four lanes, RGB888, and sync-events mode.
Those values independently match the Miix VBT almost field-for-field. The VBT
does not expose the AUO model string, so this is corroboration rather than a
firmware-derived panel identity.

References:
- https://www.panelook.com/upload/201409/B101UAN01.7_HW1A_Ver0.2_20130129_201409304892.pdf
- https://docs.amd.com/r/en-US/pg238-mipi-dsi-tx/Hardware-Validation

Hans de Goede's long-running x86-tablet hardware inventory independently
records the Miix 2 10 as a 1920x1200 DSI tablet with 24-bpp display data,
Crystal Cove PWM backlight, VBT PWM frequency 200, ELAN1001 touchscreen, and
a haptic-feedback home button. That display/touch description matches this
unit closely. His inventory lists a Z3740 CPU, while this specific tablet
reports Z3745, so the CPU entry should not be treated as an exact identity.

The VBT's PnP identity is generic/unhelpful (`MS_`, product 1) and the
panel name is merely `LFP_PanelName`. Therefore DMI + timing + external
panel documentation are more useful identifiers than the VBT PnP name.

## Backlight data

VBT block 43 reports:

- backlight type: LED;
- inverter type: PWM;
- active low: no;
- PWM frequency field: 200;
- minimum brightness: 0;
- default/full level: 255.

VBT block 44 says ALS support is enabled and includes a brightness/lux
table. Linux currently exposes `intel_backlight` under the DSI connector,
with a 0..100 brightness range.

The ACPI `GFX0.DD1F` device also provides `_BCL`, `_BCM`, and
`_BQC` methods. `_BCL` exposes levels 0 through 100; `_BCM` calls
the firmware `AINT` method and updates the stored brightness value.

## MIPI configuration

VBT block 52 reports for panel 0:

- video mode;
- RGB888;
- non-burst transfer with sync events;
- four DSI lanes;
- no dual-link;
- EOT packets enabled;
- clock-stop disabled;
- panel-power GPIO control through the PMIC;
- panel rotation 0 degrees;
- CABC unsupported.

Power-sequence timing fields are:

- panel power-on delay: 500;
- panel power-on to backlight enable: 500;
- backlight disable to panel power-off: 500;
- panel power-off delay: 500;
- panel power-cycle delay: 5000.

The VBT also contains the D-PHY timing parameters consumed by
`intel_dsi_vbt.c` / `vlv_dsi.c`.

## ACPI topology

The decompiled DSDT contains `_SB.PCI0.GFX0` at PCI address 00:02.0.
Its dependency list includes the platform power engine, I2C7, and
`I2C7.PMIC`.

The firmware also exposes Bay Trail I2C controllers and Intel PWM devices.
This is consistent with the VBT declaring PMIC-controlled MIPI panel power
and PWM/firmware-managed backlight behaviour.

## Current interpretation

The fundamental firmware description is internally consistent with the
working Linux mode: i915 obtains 1920x1200@60 over a four-lane MIPI-DSI
link and Mesa acceleration works.

There is currently no evidence that the Miix needs the existing Lenovo
Yoga Tablet 2/3 VLV DSI quirks. In particular:

- the reported physical size 216x135 mm is plausible rather than obviously
  bogus;
- no MIPI I2C timeout has yet been reproduced;
- no missing backlight-off MIPI sequence has yet been demonstrated;
- the Miix VBT has no block 53 sequence table to which the 2025
  v1/v2 sequence-fixup patch would obviously apply.

Do not synthesize a Miix-specific DMI quirk until a reproducible firmware
defect is identified.
