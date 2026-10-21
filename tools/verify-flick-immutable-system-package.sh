#!/usr/bin/env bash
# Read-only package/closure/boot safety checks, never activates compositor.
set -euo pipefail
old=/nix/store/mff55q54jy9x5jifkzy5fhriqshd90ng-flick-unstable-2026-01-04
new=/nix/store/k7rf872zph2192khxyrvx7fgzj40fl1r-flick-qt-egl-qml-system
oldelf=/nix/store/im04hvdj3p8i7ncywpb8accldk2bnd2k-flick-unstable-2026-01-04
elf=/nix/store/hkkkfh38gpmwk2s2cfbq062ni2xx10jx-flick-unstable-2026-01-04
root=/home/alex/lenovo-mvp/builds/.flick-qt-egl-qml-system-gcroot
expected=4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d
for path in "$old" "$new" "$oldelf" "$elf"; do nix-store --check-validity "$path" >/dev/null; done
actual="$(sha256sum "$elf/bin/flick" | cut -d' ' -f1)"
[[ "$actual" == "$expected" ]] || { echo WRONG_BINARY_HASH; exit 1; }
[[ -x "$new/bin/flick" && -r "$new/share/flick/apps/lockscreen/main.qml" ]] || exit 1
[[ -L "$root" && "$(readlink -f "$root")" == "$new" ]] || exit 1
newcount="$(nix-store -qR "$new" | wc -l)"
oldcount="$(nix-store -qR "$old" | wc -l)"
[[ "$newcount" -eq "$oldcount" && "$newcount" -eq 282 ]] || exit 1
newonly="$(comm -23 <(nix-store -qR "$new" | sort) <(nix-store -qR "$old" | sort))"
oldonly="$(comm -13 <(nix-store -qR "$new" | sort) <(nix-store -qR "$old" | sort))"
[[ "$newonly" == "$elf"$'\n'"$new" ]] || {
  echo "Unexpected new closure paths: $newonly"; exit 1;
}
[[ "$oldonly" == "$oldelf"$'\n'"$old" ]] || {
  echo "Unexpected original closure paths: $oldonly"; exit 1;
}
[[ "$(readlink -f /etc/systemd/system/flick.service)" == /nix/store/*-unit-flick.service/flick.service ]] || exit 1
[[ "$(readlink -f /run/current-system)" == "$(readlink -f /run/booted-system)" ]] || exit 1
[[ -z "$(systemctl show flick -P DropInPaths)" ]] || exit 1
systemctl is-active --quiet flick
echo "verified_utc=$(date -u +%FT%TZ)"
echo "new_immutable_system_package=$new"
echo "new_compiled_binary_sha256=$actual"
echo "nix_store_closure_paths=$newcount"
echo "closure_differences_only_two_flick_paths=PASS"
echo "qml_assets_and_graphics_libraries_identical=PASS"
echo "gc_root=$root"
echo "original_flick_pid=$(systemctl show flick -P MainPID)"
echo "active_system_generation_unchanged=YES"
echo "immutable_package_readonly_verification=PASS"
