#!/usr/bin/env python3
"""Prove our pinned Smithay source-contract audit fails when required APIs regress."""
from pathlib import Path
import argparse
import shutil
import subprocess
import sys
import tempfile
p=argparse.ArgumentParser()
p.add_argument("--smithay-snapshot",required=True,type=Path)
p.add_argument("--project-root",required=True,type=Path)
args=p.parse_args()
probe=args.project_root/"tools/check-flick-smithay-egl-integration.py"
def check(temp:Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable,str(probe),
        "--smithay-snapshot",str(temp),
        "--project-root",str(args.project_root)],
        text=True,capture_output=True)
with tempfile.TemporaryDirectory(prefix="smithay-contract-negative-") as root:
    snapshot=Path(root)
    for name in ("display.rs","gles.rs","renderer.rs","dmabuf.rs"):
        shutil.copy2(args.smithay_snapshot/name,snapshot/name)
    original=check(snapshot)
    assert original.returncode==0, original.stderr
    print("KNOWN_GOOD_SMITHAY_CONTRACT=PASS")
    changes=(
        ("renderer.rs","Some(BufferType::Egl)","Some(BufferType::BrokenEgl)"),
        ("display.rs",'self.extensions.has_extension("EGL_WL_bind_wayland_display")',
                       'self.extensions.has_extension("BROKEN_EGL_EXTENSION")'),
        ("gles.rs",'self.egl_reader = Some(self.egl.display().bind_wl_display(display)?)',
                   'self.egl_reader = None'),
        ("dmabuf.rs","pub fn failed(mut self)","pub fn missing_failed_api(mut self)")
    )
    for name,old,new in changes:
        path=snapshot/name
        raw=path.read_text()
        assert raw.count(old)>=1,(name,raw.count(old))
        # Smithay has two ImportAll implementation branches; remove every
        # occurrence so the negative test proves both paths are checked.
        path.write_text(raw.replace(old,new))
        bad=check(snapshot)
        assert bad.returncode!=0,(name,bad.stdout,bad.stderr)
        assert "Smithay/Flick contract failure:" in bad.stderr,(name,bad.stderr)
        print(f"NEGATIVE_API_REGRESSION_REJECTED={name}")
        path.write_text(raw)
    assert check(snapshot).returncode==0
print("FOUR_NEGATIVE_SMITHAY_CONTRACT_TESTS=PASS")
