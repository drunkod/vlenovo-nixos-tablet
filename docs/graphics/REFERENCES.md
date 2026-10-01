# Graphics-driver research references

Prefer primary documentation and upstream source when making changes.

## Linux DRM / kernel development

- DRM introduction:
  https://docs.kernel.org/gpu/introduction.html
- DRM/GPU documentation index:
  https://docs.kernel.org/gpu/
- i915 driver documentation:
  https://docs.kernel.org/gpu/i915.html
- Submitting kernel patches:
  https://docs.kernel.org/process/submitting-patches.html
- Stable-kernel rules:
  https://docs.kernel.org/process/stable-kernel-rules.html

The current upstream source paths most relevant to this tablet are listed in
`UPSTREAM.md`.

## Intel GPU testing

- IGT GPU Tools documentation:
  https://drm.pages.freedesktop.org/igt-gpu-tools/
- IGT source:
  https://gitlab.freedesktop.org/drm/igt-gpu-tools

## Mesa / Crocus development

- Mesa documentation:
  https://docs.mesa3d.org/
- Mesa build/install and development environment:
  https://docs.mesa3d.org/install.html
- Graphics debugging:
  https://docs.mesa3d.org/graphics-debugging/debugging-misrenderings-crashes.html
- Gallium introduction:
  https://docs.mesa3d.org/gallium/intro.html
- Mesa source:
  https://gitlab.freedesktop.org/mesa/mesa

## Intel Bay Trail documentation

- Intel Bay Trail graphics developer-reference index:
  https://www.intel.com/content/www/us/en/docs/graphics-for-linux/developer-reference/1-0/bay-trail.html
- Hans de Goede's x86-tablet hardware inventory (contains a dedicated Miix 2 10 entry):
  https://github.com/jwrdegoede/sunxi-fedora-scripts/blob/master/x86-tablet-info

The Bay Trail PRM set includes GPU architecture, memory, command-stream,
3D/media, blitter and display documentation. Use it to understand hardware
registers and command semantics instead of reverse engineering a Windows
binary first.

## NixOS

- NixOS manual:
  https://nixos.org/manual/nixos/stable/
- NixOS model / generations:
  https://nixos.org/guides/how-nix-works/
- Accelerated video playback:
  https://wiki.nixos.org/wiki/Accelerated_Video_Playback

## Bay Trail media archaeology

- Preserved Intel Bay Trail EMGD/SNA source drop and patches:
  https://github.com/jameshilliard/Intel_BYT_SNA64_EMGD_V37.40.25_RC_2015-06-02_3900
- Its VP8/VXD392/IPVR setup notes:
  https://github.com/jameshilliard/Intel_BYT_SNA64_EMGD_V37.40.25_RC_2015-06-02_3900/blob/master/patches/common/VA_Driver_i965/VP8/README_VP8_setup.txt

## Relevant upstream commits

Existing Lenovo Valleyview DSI quirk examples:

- Yoga Tablet 2 I2C bus and panel-size fix:
  https://github.com/torvalds/linux/commit/2cac4ed99f9e798df8a4c34a8399adf3c587ccba
- Yoga Tab 3 backlight/I2C fix:
  https://github.com/torvalds/linux/commit/f6f4a0862bde6c2a15654da624dc8509bf66d87e
- Follow-up DMI-match relaxation:
  https://github.com/torvalds/linux/commit/7d058e6bac9afab6a406e34344ebbfd3068bb2d5

Panel cross-checks:

- AUO B101UAN01.7 functional specification (typical 148.35 MHz,
  1920x1200, 2040x1212 totals):
  https://www.panelook.com/upload/201409/B101UAN01.7_HW1A_Ver0.2_20130129_201409304892.pdf
- AMD MIPI-DSI interoperability validation using B101UAN01.7 with four lanes,
  RGB888 and sync events at 1920x1200@60:
  https://docs.amd.com/r/en-US/pg238-mipi-dsi-tx/Hardware-Validation

Historical same-family evidence:

- Old Valleyview DSI clock-gating fix later reported to fix panel init on a
  Lenovo Miix 2 8:
  https://github.com/torvalds/linux/commit/721d484563e1a51ada760089c490cbc47e909756
- 2017 report/backport test on the Miix 2 8:
  https://lists.openwall.net/linux-kernel/2017/02/17/102

Valleyview/Cherryview PSR archaeology (not applicable to this DSI panel):

- Initial VLV/CHV PSR enable path:
  https://github.com/torvalds/linux/commit/b32c6f482dc56c52169cad7c9d35908c020dd22d
- Brief default enable and revert after vblank timeout problems:
  https://github.com/torvalds/linux/commit/a38c274faad0ec6aba692e294ec751d04dbba803
  https://github.com/torvalds/linux/commit/dcb2e993f3c0cecc6c0d905cbf2e428640a957c1
- Removal because of known issues, maintenance burden and no CI coverage:
  https://github.com/torvalds/linux/commit/ce3508fd2a778e9366ab638f4e1dbe6dab874c5b

Post-6.12 changes screened during this research:

- Valleyview DSI min-CDCLK extraction/refactor:
  https://github.com/torvalds/linux/commit/95601c60b1bef0cae3567b6a8816aacdd72bc340
  https://github.com/torvalds/linux/commit/252cea7f0fb41057c899bdfdd78f1b04a1ffe75d
- Explicit VBT-to-MIPI pixel-format conversion:
  https://github.com/torvalds/linux/commit/ef0430f5d3ab5b9e9e31e7534e1ebbd01ea587dc
- VLV v1/v2 MIPI sequence fixup:
  https://github.com/torvalds/linux/commit/e778689390c71462a099b5d6e56d71c316486184
- Later VLV DPHY NULL-deref fix:
  https://github.com/torvalds/linux/commit/7da6c155a67d42a0c1e4e22bd3f492fabcb14f2c
- Newer-generation DSI prepare timing change:
  https://github.com/torvalds/linux/commit/ca677505e4776bd1abf90096f3eab3b68079dde9

None of these is currently selected as a Miix 2 10 backport.
