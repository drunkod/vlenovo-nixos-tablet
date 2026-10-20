# Native DRM validated DMA-BUF candidate — not yet compiled

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
  the seventh logging patch. **Not yet compiled or activated.**

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
