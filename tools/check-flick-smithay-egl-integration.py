#!/usr/bin/env python3
"""Pinned Smithay source-contract audit for native Flick Wayland EGL integration."""
from pathlib import Path
import argparse
import re
p=argparse.ArgumentParser()
p.add_argument("--smithay-snapshot",type=Path,required=True)
p.add_argument("--project-root",type=Path,required=True)
args=p.parse_args()
a=args.smithay_snapshot
r=args.project_root
display=(a/"display.rs").read_text()
gles=(a/"gles.rs").read_text()
renderer=(a/"renderer.rs").read_text()
dmabuf=(a/"dmabuf.rs").read_text()
patch=(r/"experiments/flick-build/patches/flick/0010-enable-qt-wl-drm-egl-import.patch").read_text()
dma_patch=(r/"experiments/flick-build/patches/flick/0009-native-drm-validated-dmabuf.patch").read_text()
def requires(condition,message):
    assert condition,"Smithay/Flick contract failure: "+message
requires('fn bind_wl_display(&self, display: &DisplayHandle)' in display,
         "EGLDisplay lacks bind_wl_display")
requires('self.extensions.has_extension("EGL_WL_bind_wayland_display")' in display,
         "EGL extension support not checked")
requires('ffi::egl::BindWaylandDisplayWL' in display,
         "Wayland EGL display not bound")
requires('impl ImportEgl for GlesRenderer' in gles and
         'self.egl_reader = Some(self.egl.display().bind_wl_display(display)?)' in gles,
         "GlesRenderer not wired to EGL buffer reader")
requires('feature = "use_system_lib"' in gles and
         'feature = "wayland_frontend"' in gles,
         "GLES ImportEgl feature gating unknown")
requires('impl<R: Renderer + ImportMemWl + ImportEgl + ImportDmaWl> ImportAll for R' in renderer,
         "ImportAll does not include EGL import capability")
requires('Some(BufferType::Egl) => Some(self.import_egl_buffer(buffer, surface, damage))' in renderer,
         "ImportAll does not dispatch EGL wl_buffer")
requires('self.inner.created(&buffer);' in dmabuf and
         'pub fn successful<D>(mut self)' in dmabuf,
         "DMA-BUF notifier successful path changed")
requires('pub fn failed(mut self)' in dmabuf and
         'self.inner.failed()' in dmabuf,
         "DMA-BUF notifier failure path changed")
requires('self.pending_dmabuf_imports.push((dmabuf, notifier));' in dma_patch and
         'notifier.failed();' in dma_patch and
         'notifier.successful::<Flick>()' in dma_patch,
         "Flick importer notifier path incomplete")
requires('renderer.bind_wl_display(&state.display_handle)' in patch and
         '"use_system_lib"' in patch,
         "Flick patch does not enable Smithay Egl wl_buffer handling")
print("PINNED_SMITHAY_EGL_BIND_WL_DISPLAY=PASS")
print("PINNED_SMITHAY_FEATURE_GATED_IMPORT_EGL=PASS")
print("PINNED_SMITHAY_IMPORT_ALL_EGL_WL_BUFFER=PASS")
print("PINNED_SMITHAY_DMABUF_IMPORT_NOTIFIER_CONTRACT=PASS")
print("FLICK_NATIVE_DRM_EGL_AND_DMABUF_INTEGRATION_CONTRACT=PASS")
print("STATIC_SOURCE_CONTRACTS_ONLY_NO_LIVE_COMPOSITOR_TEST=YES")
