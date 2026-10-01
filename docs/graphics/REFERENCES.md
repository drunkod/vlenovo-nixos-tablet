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

The Bay Trail PRM set includes GPU architecture, memory, command-stream,
3D/media, blitter and display documentation. Use it to understand hardware
registers and command semantics instead of reverse engineering a Windows
binary first.

## NixOS

- NixOS manual:
  https://nixos.org/manual/nixos/stable/
- NixOS model / generations:
  https://nixos.org/guides/how-nix-works/

## Relevant upstream commits

Existing Lenovo Valleyview DSI quirk examples:

- Yoga Tablet 2 I2C bus and panel-size fix:
  https://github.com/torvalds/linux/commit/2cac4ed99f9e798df8a4c34a8399adf3c587ccba
- Yoga Tab 3 backlight/I2C fix:
  https://github.com/torvalds/linux/commit/f6f4a0862bde6c2a15654da624dc8509bf66d87e
- Follow-up DMI-match relaxation:
  https://github.com/torvalds/linux/commit/7d058e6bac9afab6a406e34344ebbfd3068bb2d5

Post-6.12 changes screened during this research:

- VLV v1/v2 MIPI sequence fixup:
  https://github.com/torvalds/linux/commit/e778689390c71462a099b5d6e56d71c316486184
- Later VLV DPHY NULL-deref fix:
  https://github.com/torvalds/linux/commit/7da6c155a67d42a0c1e4e22bd3f492fabcb14f2c
- Newer-generation DSI prepare timing change:
  https://github.com/torvalds/linux/commit/ca677505e4776bd1abf90096f3eab3b68079dde9

None of these is currently selected as a Miix 2 10 backport.
