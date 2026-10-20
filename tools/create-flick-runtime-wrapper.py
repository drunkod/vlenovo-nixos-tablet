#!/usr/bin/env python3
"""Create a staged user-owned launcher mirroring an installed Nix wrapper.

No service or system-generation change. Reads original NixOS wrapper and a
hash-verified ELF from tablet user's builds folder, and atomically writes an
unactivated wrapper in the SAME folder. Prevents accidental library-path loss.
"""
from pathlib import Path
import argparse
import hashlib
import os
import re
import tempfile

TARGET_LINE = re.compile(
    r'^exec -a "\$0" "([^"\n]+)"\s+"\$@"\s*$',
    re.MULTILINE,
)

def generate(installed: Path, target: Path, output: Path, expected_sha: str):
    if not re.fullmatch(r"[a-f0-9]{64}", expected_sha):
        raise ValueError("expected SHA-256 must be 64 lowercase hex characters")
    if target.parent != output.parent or target.is_symlink():
        raise ValueError("target and wrapper must be ordinary files in same staging directory")
    if not target.name.startswith("flick-") or not output.name.startswith(".launch-flick-"):
        raise ValueError("unexpected target/wrapper name; fail closed")
    if output.exists() or output.is_symlink():
        raise ValueError("refusing to overwrite existing launcher")
    if not target.is_file() or not os.access(target,os.X_OK):
        raise ValueError("candidate executable missing")
    content=target.read_bytes()
    if content[:4]!=b"\x7fELF":
        raise ValueError("candidate is not ELF")
    sha=hashlib.sha256(content).hexdigest()
    if sha!=expected_sha:
        raise ValueError("candidate checksum does not match pinned build")
    original=installed.read_text()
    if not original.startswith("#! /nix/store/"):
        raise ValueError("expected an original Nix-generated shebang")
    if "export FLICK_ROOT=" not in original or "LD_LIBRARY_PATH" not in original:
        raise ValueError("original launcher lacks essential Flick runtime environment")
    matches=list(TARGET_LINE.finditer(original))
    if len(matches)!=1:
        raise ValueError("original launcher's final exec cannot be identified uniquely")
    match=matches[0]
    if not match.group(1).endswith("/bin/.flick-wrapped"):
        raise ValueError("installed wrapper does not launch original Flick")
    changed=original[:match.start()]+f'exec -a "$0" "{target}"  "$@"'+original[match.end():]
    if changed.count(str(target))!=1 or changed.count("export FLICK_ROOT=")!=1:
        raise ValueError("invalid generated launcher")
    with tempfile.NamedTemporaryFile(mode="w",encoding="utf-8",
                                     dir=output.parent,prefix=".flick-wrapper-",
                                     delete=False) as tmp:
        temp=Path(tmp.name)
        tmp.write(changed)
        tmp.flush()
        os.fsync(tmp.fileno())
    try:
        temp.chmod(0o755)
        temp.replace(output)
    finally:
        if temp.exists():
            temp.unlink()
    return sha

if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--installed",type=Path,required=True)
    p.add_argument("--candidate",type=Path,required=True)
    p.add_argument("--launcher",type=Path,required=True)
    p.add_argument("--sha256",required=True)
    a=p.parse_args()
    try:
        sha=generate(a.installed,a.candidate,a.launcher,a.sha256)
    except (OSError,ValueError) as exc:
        p.error(str(exc))
    print(f"candidate_sha256={sha}")
    print(f"staged_wrapper_only={a.launcher}")
    print("running_compositor=UNCHANGED")
