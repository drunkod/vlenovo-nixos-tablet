# Bay Trail media acceleration

The 3D driver and the fixed-function video driver are separate parts of the
Linux graphics stack. Mesa Crocus already accelerates OpenGL on this tablet,
but the baseline NixOS system did not have a VA-API driver installed under
`/run/opengl-driver/lib/dri`.

## Live VA-API probe

A temporary, non-system test used nixpkgs `intel-vaapi-driver` with
`libva-utils` against `/dev/dri/renderD128`.

The driver initialized successfully as:

```text
Intel i965 driver for Intel(R) Bay Trail
LIBVA driver: i965
```

This proves the current upstream userspace driver can use the tablet's Bay
Trail media hardware without replacing i915.

## Advertised hardware profiles

The live `vainfo` test exposed:

- MPEG-2 Simple/Main decode, plus encode;
- H.264 Constrained Baseline/Main/High decode, plus encode;
- H.264 Stereo High decode;
- VC-1 Simple/Main/Advanced decode;
- JPEG Baseline decode;
- video processing.

VP8, VP9, and HEVC were not exposed by this modern i965 test.

For normal H.264/MPEG-2/VC-1/JPEG playback, the missing NixOS package is
therefore a more immediate performance issue than the kernel graphics driver.

## Historical Intel Bay Trail stack

A 2015 Intel EMGD/Valleyview source drop preserved on GitHub contains a
separate VP8 path. Its documentation says Bay Trail VP8 used the VXD392
engine through an `ipvr` DRM module, an EMGD kernel driver, a patched libdrm,
a PSB/libva wrapper, and a patched GStreamer VA-API stack.

That historical recipe targeted Linux LTSI 3.10.61 and explicitly instructed
users to disable i915. It is useful source archaeology, but it is not suitable
as a drop-in driver for the current Linux 6.12/NixOS system.

The preserved source is useful if a specific VP8 requirement justifies
investigating the old VXD392/IPVR implementation. Any such work should first
check whether a modern upstream media API already supports the hardware.

## NixOS integration test

The maintained NixOS integration was then tested with:

```nix
hardware.graphics.extraPackages = with pkgs; [
  intel-vaapi-driver
];
```

A before/after capture was taken with all `LIBVA_*` overrides removed.
Before the change, `vainfo` searched `/run/opengl-driver/lib/dri` but could
not find a usable Intel VA driver and initialization failed. In the test
generation, `i965_drv_video.so` appeared in `/run/opengl-driver/lib/dri` and
libva automatically fell back from `iHD` to `i965`; initialization succeeded.

The same capture comparison showed no change to the DRM connector state,
OpenGL renderer, i915 display state, i915 capabilities, runtime-PM state, or
VBT hash. GPU reset count stayed at 0 and `ERROR` stayed `0x00000000`.

This makes `intel-vaapi-driver` a narrowly scoped userspace improvement for
hardware video acceleration. It does not replace i915, Crocus, the DSI
display path, or Sway. The change is currently being exercised as a NixOS
`test` generation before any permanent switch.
