#!/usr/bin/env python3
"""Zero GPU calls: CLI fails closed before loading any shared libraries."""
from pathlib import Path
import subprocess
import sys
script=Path(__file__).with_name("private-wl-drm-egl-probe.py")
base=[sys.executable,str(script),"--egl-lib","unused","--gbm-lib","unused","--wayland-lib","unused"]
for suffix, expected in [
    (["--runtime","/tmp/flick-probe"],"private subdirectory"),
    (["--runtime","/run/user/999/private-test","--seconds","999"],"3..90"),
    (["--runtime","/run/user/999/private-test","--socket","../wayland-1"],"socket name"),
]:
    r=subprocess.run(base+suffix,capture_output=True,text=True)
    assert r.returncode==2,(r.returncode,r.stdout,r.stderr)
    assert expected in r.stderr,(expected,r.stderr)
print("PRIVATE_WAYLAND_SERVER_CLI_SAFETY=PASS (3 cases)")
