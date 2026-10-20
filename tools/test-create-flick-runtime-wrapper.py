#!/usr/bin/env python3
import hashlib
import importlib.util
from pathlib import Path
import tempfile
p=Path(__file__).with_name("create-flick-runtime-wrapper.py")
spec=importlib.util.spec_from_file_location("wrapper_script",p)
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
with tempfile.TemporaryDirectory() as tmp:
    root=Path(tmp)
    template=root/"original"
    template.write_text('#! /nix/store/abc-bash/bin/bash -e\n'
      "export FLICK_ROOT='/nix/store/good/share/flick'\n"
      "LD_LIBRARY_PATH='/nix/store/good/lib':$LD_LIBRARY_PATH\n"
      'exec -a "$0" "/nix/store/good/bin/.flick-wrapped"  "$@" \n')
    binary=root/"flick-experimental-test";binary.write_bytes(b"\x7fELFtest")
    binary.chmod(0o755)
    digest=hashlib.sha256(binary.read_bytes()).hexdigest()
    output=root/".launch-flick-experimental-test"
    assert m.generate(template,binary,output,digest)==digest
    text=output.read_text()
    assert f'exec -a "$0" "{binary}"' in text
    assert "export FLICK_ROOT='/nix/store/good/share/flick'" in text
    assert str(output) not in text
    try:m.generate(template,binary,output,digest)
    except ValueError:pass
    else:raise AssertionError("overwrite allowed")
    output.unlink()
    try:m.generate(template,binary,output,"0"*64)
    except ValueError:pass
    else:raise AssertionError("wrong sha accepted")
    binary.write_bytes(b"no-elf")
    try:m.generate(template,binary,output,hashlib.sha256(binary.read_bytes()).hexdigest())
    except ValueError:pass
    else:raise AssertionError("non-ELF accepted")
print("FLICK_WRAPPER_NEGATIVE_AND_POSITIVE_TESTS=PASS")
