#!/usr/bin/env python3
"""Test the exact recovery shell logic with harmless temporary paths/mock systemctl.

Never runs the real systemctl or touches /run/systemd/system. Safe on Mac/Linux.
"""
from pathlib import Path
import os
import subprocess
import tempfile

source = Path(__file__).with_name("flick-guard-rollback.sh").read_text()

with tempfile.TemporaryDirectory(prefix="flick-rollback-mock-") as tmp:
    root = Path(tmp)
    fake = root / "bin"
    fake.mkdir()
    calls = root / "calls"
    mockctl = fake / "systemctl"
    mockctl.write_text(
        "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$FLICK_MOCK_CALLS\"\n"
    )
    mockctl.chmod(0o755)
    permanent = root / "etc" / "flick.service"
    permanent.parent.mkdir()
    permanent.write_text("[Service]\nExecStart=/nix/store/known-good/bin/flick\n")
    override = root / "run" / "90-vlenovo-gpu-trial.conf"
    override.parent.mkdir()
    executable = root / "rollback.sh"
    assert "OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf" in source
    assert "ORIGINAL=/etc/systemd/system/flick.service" in source
    assert "UNIT=flick.service" in source
    guard = "if (( EUID != 0 )); then\n    echo 'Rollback requires system/root privileges' >&2\n    exit 77\nfi"
    assert guard in source
    # Preserve the mock systemctl on the harness PATH; the production script
    # intentionally uses the tablet's NixOS PATH instead of a caller's PATH.
    source_for_mock = source.replace(
        "export PATH=/run/current-system/sw/bin:/usr/bin:/bin",
        'export PATH="$PATH"',
    )
    tested = source_for_mock.replace(
        "OVERRIDE=/run/systemd/system/flick.service.d/90-vlenovo-gpu-trial.conf",
        f"OVERRIDE={override}",
    ).replace(
        "ORIGINAL=/etc/systemd/system/flick.service", f"ORIGINAL={permanent}"
    ).replace(guard, "# Root privilege checked separately in production")
    executable.write_text(tested)
    executable.chmod(0o700)
    env = dict(os.environ, PATH=str(fake) + os.pathsep + os.environ["PATH"],
               FLICK_MOCK_CALLS=str(calls))

    def invoke():
        return subprocess.run(["bash", str(executable)], env=env, capture_output=True, text=True)

    # 1. Idempotence: no override => no restart or systemctl activity.
    first = invoke()
    assert first.returncode == 0, first.stderr
    assert not calls.exists(), calls.read_text() if calls.exists() else ""
    print("PASS: absent override never restarts Flick")

    # 2. Fail closed: an unmarked /run drop-in is untouched.
    override.write_text("[Service]\nExecStart=/bogus\n")
    reject = invoke()
    assert reject.returncode == 78, reject
    assert override.exists() and not calls.exists()
    print("PASS: unmarked override is refused")

    # 3. Fail closed: never dereference a symlinked override.
    override.unlink()
    target = root / "target"
    target.write_text("# VLENOVO_FLICK_GPU_TRIAL=1\n")
    override.symlink_to(target)
    reject_link = invoke()
    assert reject_link.returncode == 78 and target.exists() and not calls.exists()
    override.unlink()
    print("PASS: symlink override is refused")

    # 4. With a correctly marked override, verify recovery order.
    override.write_text("# VLENOVO_FLICK_GPU_TRIAL=1\n[Service]\nExecStart=\n")
    good = invoke()
    assert good.returncode == 0, good.stderr
    assert not override.exists()
    assert permanent.read_text() == "[Service]\nExecStart=/nix/store/known-good/bin/flick\n"
    lines = calls.read_text().splitlines()
    assert lines == [
        "daemon-reload", "reset-failed flick.service",
        "restart flick.service", "is-active --quiet flick.service"
    ], lines
    print("PASS: marked override removed, daemon reload before restart")
    print("PASS: original service definition preserved")

    # 5. Running recovery again does not restart a healthy service.
    again = invoke()
    assert again.returncode == 0 and len(calls.read_text().splitlines()) == 4
    print("PASS: rollback is idempotent")
print("ALL_MOCK_ROLLBACK_CHECKS_PASSED")
