# Bay Trail media acceleration

> **Live update, 2026-10-20:** the currently booted NixOS generation `91jbl1ir…` **does contain** `i965_drv_video.so` in `/run/opengl-driver/lib/dri`. A fresh `vainfo --display drm --device /dev/dri/renderD128` with no `LIBVA_*` overrides successfully initialized Intel i965 Bay Trail and advertised H.264, MPEG-2, VC-1 and JPEG decode profiles. The missing-driver observations below refer to earlier generations and are preserved as historical evidence. See `HARDWARE_ACCELERATION_AUDIT_2026-10-20.md` for the current GPU/Slint A/B tests. Driver availability is not proof of hardware decode in a particular video player.

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

## H.264 decode benchmark

A reproducible 12-second 1920x1080@30 H.264 test clip was decoded three times
with FFmpeg 7.1.1. Software decoding used four CPU threads. The VA-API test
used `/dev/dri/renderD128`, the i965 Bay Trail driver, and
`-hwaccel_output_format vaapi` so decoded frames stayed on the GPU.

Software decode averaged about 5.5x realtime with about 7.44 CPU-seconds per
run. Direct VA-API decode averaged about 16.0x realtime with about 1.03
CPU-seconds per run. In other words, the fixed-function path was roughly 2.9x
faster in this synthetic decode-only test while consuming about 86% fewer CPU
seconds.

`intel_gpu_top` independently observed the `Video` engine active during the
VA-API run (four sampled active intervals, peak 100%, mean active sample about
62.9%). Render/3D and Blitter stayed idle in that capture, which is consistent
with fixed-function video decode rather than a Crocus 3D workload.

A VA-API run which allowed FFmpeg to download every decoded frame back to CPU
memory was much slower (roughly 1.6-1.9x realtime). That is not evidence that
hardware decode is slow; it demonstrates the cost of a forced GPU-to-CPU frame
transfer. Real players should keep frames in hardware/DMABUF paths where
possible.

After the tests i915 still reported reset count 0, `ERROR=0x00000000`, no new
kernel GPU warnings, and zero failed systemd units.

Use `tools/benchmark-vaapi INPUT.mp4` from `nix develop .#graphics` to repeat
the software/direct-VA-API comparison.

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

The NixOS integration was then tested with:

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
display path, or Sway. It was exercised as a NixOS `test` generation, not
made permanent. See the current-state probe below; the tablet has since
returned to the permanent generation without the system VA driver.

## Read-only recheck — 2026-10-02

Current runtime and permanent profile both point to generation
`4nccr8wjih2g6dsjlxcyi5d7v7354m2n`; kernel remains 6.12.36. The system
`/run/opengl-driver/lib/dri` lacks `i965_drv_video.so`.

Executed `vainfo --display drm --device /dev/dri/renderD128` with both
`LIBVA_DRIVER_NAME` and `LIBVA_DRIVERS_PATH` unset: initialization failed.
Repeated against the already available Nix-store `intel-vaapi-driver` with
explicit per-process overrides: initialization succeeded as Intel i965 Bay
Trail, with the decode profiles listed above. This does not require activation,
a kernel change, a compositor restart, or a patched Crocus library.

No HEVC, VP9, AV1 or VP8 decoding profile was advertised. Ordinary H.264 High
is not H.264 High 10: use 8-bit 4:2:0 H.264 as the first target. Advertised
profiles alone do not establish every supported resolution, frame rate or
stream feature; test representative content.

The supplied OpenGL playback A/B logs show `VO: [gpu-next] ... yuv420p` without
hardware-decoding confirmation. Selecting OpenGL chooses a rendering API, not
a decoder. The installed mpv 0.40.0 reports `hwdec=no` as its default. Do not
interpret the small Crocus playback difference as a VA-API comparison.

## Temporary mpv playback test (recommended, not executed in this review)

Run on the tablet in a terminal inside the existing Sway session. From the
repository checkout, enter the graphics shell interactively so its shell hook
sets the i965 driver name and Nix-store search path:

```sh
nix develop .#graphics
vainfo --display drm --device /dev/dri/renderD128
```

This tests the shell-provided driver, not system installation. The graphics
shell does not include mpv, so use the same pinned nixpkgs revision for it:

```sh
nix shell github:NixOS/nixpkgs/88983d4b665fb491861005137ce2b11a9f89f203#mpv \
  --command mpv --no-config --vo=gpu \
  --gpu-api=opengl --gpu-context=wayland \
  --hwdec=vaapi --hwdec-codecs=h264 \
  --log-file=/tmp/mpv-vaapi.log -v VIDEO.mp4
```

`VIDEO.mp4` is a template: replace it with an actual known H.264 8-bit file.
The child process inherits the graphics shell's `LIBVA_*` overrides. Do not
use experimental `LD_LIBRARY_PATH` overrides for this media test; keep the
system Crocus rendering stack as the unchanged control. mpv may still fall
back to software, so verify the actual outcome instead of trusting the option.

Check the log for `Using hardware decoding (vaapi)` and for any subsequent
software fallback. The runtime `hwdec-current` property must report `vaapi`;
the configured `hwdec` option alone is not evidence. Press `i` for playback
statistics, and use mpv's console/IPC to inspect `hwdec-current` if needed.

In a second graphics-shell terminal, run the shell's GPU monitor via its
absolute path (sudo may otherwise discard the shell PATH):

```sh
sudo "$(command -v intel_gpu_top)"
```

Watch the **Video/BSD engine**, not only Render/3D. Compare otherwise identical
runs with `--hwdec=no`, `--hwdec=vaapi` and `--hwdec=vaapi-copy`, preserving
logs, user/system CPU time and dropped frames. Real-time playback duration is
mostly determined by the clip length; a tiny wall-time difference is not a
throughput gain. Use longer repeated trials and distinguish startup drops from
steady-state drops.

Prefer direct `vaapi`: surfaces remain on the GPU for presentation without a
CPU readback. This is often called zero-copy but does not guarantee absolutely
no GPU-side copies. If direct EGL import fails or produces corruption, test
`vaapi-copy` as a compatibility fallback; it copies frames into system RAM and
may lose much of the benefit on Bay Trail.

Start without interpolation, custom shaders or a high-quality rendering
profile. If rendering remains the bottleneck, separately compare inexpensive
bilinear scaling. Do not change scaling and the decoder simultaneously in an
attribution experiment.

## Browser playback

Validate mpv first, then investigate the installed browser version separately.
Check Firefox `about:support`, or Chromium `chrome://gpu` and
`chrome://media-internals`, and correlate playback with Video-engine activity.
Hardware compositing is not proof of hardware video decoding. Browser feature
flags/preferences and sandbox access are version-specific; do not copy a
historical flag list blindly or disable the browser sandbox to obtain VA-API.

For YouTube, inspect Stats for nerds: prefer `avc1` (H.264), not `vp09` (VP9)
or `av01` (AV1). Requesting H.264 via a codec-selection extension may help but
is not itself proof of acceleration. Start at 720p30, then test 1080p30; avoid
assuming 1080p60 or unsupported codecs will work well on this Atom.

## Deployment and maintenance

The repository already declares `intel-vaapi-driver` in
`nixos/common-configuration.nix`; the permanent profile does not contain it.
Testing it in an interactive shell preserves that profile. If explicitly
approved later, the existing NixOS userspace configuration can be built/tested
without changing the running kernel. Do not switch permanently as part of
research.

> VA-API was validated in the temporary runtime; the permanent system profile remains unchanged.

Intel has discontinued upstream maintenance of `intel-vaapi-driver`, including
security fixes. `intel-media-driver`/iHD is not a Bay Trail replacement: its
supported platform list starts at Broadwell. Retain the legacy-maintenance
caveat and avoid treating generic newer-Intel advice as applicable to this GPU.

Sources:

- https://mpv.io/manual/stable/ — decoder selection, direct/copy paths and `hwdec-current`.
- https://wiki.nixos.org/wiki/Accelerated_Video_Playback — graphics extraPackages and player configuration.
- https://github.com/intel/intel-vaapi-driver — legacy driver and discontinuation notice.
- https://github.com/intel/media-driver/blob/master/README.md — iHD platform support.
- https://chromium.googlesource.com/chromium/src/+/main/docs/gpu/vaapi.md — browser verification and limitations.
