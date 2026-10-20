#!/usr/bin/env python3
"""Static integration guard for built Flick native DRM patch stack.

Must run on a real reconstructed source checkout AFTER six NixOS patches.
This is deliberately not a substitute for compiler or live compositor tests.
"""
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile
import re

parser=argparse.ArgumentParser()
parser.add_argument("--root",type=Path,required=True)
parser.add_argument("--source",type=Path,required=True)
a=parser.parse_args()
patches=a.root/"experiments/flick-build/patches/flick"
files=("shell/src/backend/udev.rs","shell/src/state.rs","shell/Cargo.toml")
with tempfile.TemporaryDirectory(prefix="flick-guard-integrity-") as work:
    tmp=Path(work)
    for f in files:
        dest=tmp/f
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(a.source/f,dest)
    for n in ("0007-throttle-render-info-logs.patch",
              "0008-skip-qml-obscured-slint-render.patch",
              "0009-native-drm-validated-dmabuf.patch",
              "0010-enable-qt-wl-drm-egl-import.patch"):
        patch=patches/n
        cmd=["git","apply"]
        if n.startswith("0007"):
            cmd += ["--unidiff-zero"]
        cmd += [str(patch)]
        subprocess.run(cmd,cwd=tmp,check=True,capture_output=True)
    u=(tmp/"shell/src/backend/udev.rs").read_text()
    state=(tmp/"shell/src/state.rs").read_text()
    cargo=(tmp/"shell/Cargo.toml").read_text()

    # The QML-specific Slint suppression predicate must agree exactly with
    # the existing QML lock-screen render branch, not only an app count.
    guard=re.search(
        r"let qml_lock_covers_slint\s*=\s*([^;]+);",u)
    branch=re.search(
        r"else if (shell_view == ShellView::LockScreen\s*&&\s*"
        r"state.shell.lock_screen_active\s*&&\s*"
        r"state.space.elements\(\).count\(\)\s*>\s*0)\s*\{",u)
    assert guard is not None and branch is not None, "missing QML lock guards"
    simplify=lambda t:re.sub(r"\s+","",t)
    assert simplify(guard.group(1))==simplify(branch.group(1)), \
        "Slint suppression diverges from QML-only render branch"
    renderpos=u.index("slint_ui.process_events();")
    skippage=u.index("if !qml_lock_covers_slint {")
    copypos=u.index("buffer.copy_from_slice(&pixels_clone);",renderpos)
    qmlbranch=u.index("RENDER BRANCH: LockScreen with QML app")
    keyboardpos=u.index("Lock screen: rendering keyboard overlay on top of QML app")
    assert renderpos < skippage < copypos < qmlbranch < keyboardpos, \
        "incorrect Slint skip/keyboard event ordering"
    assert 'slint_ui.render()' in u[skippage:qmlbranch], \
        "Slint rendering accidentally moved outside its guard"
    assert u.count("bind_wl_display(&state.display_handle)") == 1
    assert '"use_system_lib"' in cargo
    assert 'renderer.import_dmabuf(&dmabuf, None)' in u
    assert 'pending_dmabuf_imports' in state and 'pending_dmabuf_imports' in u
    callback=state.split("impl DmabufHandler for Flick",1)[1]
    assert 'if self.native_dmabuf_validation {' in callback
    assert 'self.pending_dmabuf_imports.push((dmabuf, notifier));' in callback
    print("PASS: matching QML visibility predicates, Slint process_events and keyboard render ordering")
    print("PASS: EGL wl_drm binding, Smithay use_system_lib and real GPU DMA-BUF validation signatures")
    print("PASS: all four ordered patches applied on reconstructed native DRM source")
