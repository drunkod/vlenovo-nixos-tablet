# Native DRM validated DMA-BUF candidate — compiled, staged; not activated

This independent, experimental candidate addresses the verified absence of
\`zwp_linux_dmabuf_v1\` in the tablet's Flick Wayland registry and Qt Quick's
four \`llvmpipe\` worker threads. Neither observation establishes causation:
Qt 5.15's Wayland-EGL backend may also depend on \`wl_drm\`.

## Source change

- Uses \`DrmNode::from_file(&fd)\` and \`node_with_type(NodeType::Render)\`
  to match the GPU's own render node, rather than choosing an arbitrary device.
- Advertises a version-4 Smithay DMA-BUF global only when an EGL-reported
  format list is nonempty and \`DmabufFeedbackBuilder\` succeeds.
- Adds \`pending_dmabuf_imports\` to Flick's Wayland state. The current native
  GlesRenderer is local to the DRM loop, not owned by Wayland callbacks.
  Callbacks enqueue \`(Dmabuf, ImportNotifier)\`; the owning DRM loop imports
  buffers into \`gpu.renderer\` after dispatching client requests. Success is
  signaled **only** after actual import; failures notify the client.
- Leaves HWC's existing import response and its separate global unchanged,
  and preserves native \`wl_shm\` fallback if DMA-BUF cannot be initialized.
- Its source patch has passed \`git apply --check\`, \`git apply\` and
  \`patch --dry-run\` on the reconstructed deployed Flick source plus
  the seventh logging patch. **Compiled and staged, but not activated.**

## Next checks

1. Compile \`nix build path:/work#packages.x86_64-linux.flick-dmabuf-experimental
   --no-link -L\` in the existing MacBook Colima/Rosetta x86_64 Linux builder
   (with container-local \`sandbox=false\`, \`filter-syscalls=false\`, 2 jobs).
2. Resolve any Rust API/lifetime errors without changing the working baseline.
   Verify that the Nix patch phase and packaging succeed.
3. Use the existing ELF/Nix-closure/hash verifier (extend to this variant),
   but stage **without activation**.
4. Before any graphics-session restart, arrange physical access, known-good
   binary/generation rollback, a timeout recovery service and a side-channel
   SSH check. Do not switch the sole compositor based on a successful build.
5. On a safe temporary activation: check \`wayland-info\` for
   \`zwp_linux_dmabuf_v1\`, \`qmlscene\` libGL driver and render-node FDs,
   0 \`llvmpipe-*\` threads, whether the QML scene displays correctly, buffer
   import/rejection logs, touch, unlock, keyboard, desktop app composition,
   i915 errors, memory and idle CPU. Roll back immediately on failures.

The prior QML Slint render-skip and logging-only binaries remain separately
staged and are not modified by this experiment.


## Outcome: successful build and safe tablet staging

The isolated x86_64 Linux release build succeeded on the MacBook (23 min 29 sec). Nix output is /nix/store/3bbhjcb0f678069dn7l112iazk2ak5wn-flick-unstable-2026-01-04, executable SHA-256 a049d7b41bcd9939831a94a54e764b437d3c879127ba52670a4d943848b12b2c. Architecture, Nix store integrity, runtime references and both Mac and tablet --help tests passed. The byte-identical executable is staged in /home/alex/lenovo-mvp/builds/flick-dmabuf-experimental-x86_64. It was **not activated**. Detailed evidence: FLICK_DMABUF_BUILD_RESULT_2026-10-21.md. The older development checklist remains for historical context; compilation is complete but GUI performance and safety are not established.
