#!/usr/bin/env bash
# Read-only physical tablet Flick compositor deployment preflight.
# Do not turn this into an automatic activation or systemd restart script.
set -euo pipefail
echo "sample_utc=$(date -u +%FT%TZ)"
echo "flick_unit=$(systemctl show flick -P FragmentPath)"
echo "flick_active=$(systemctl is-active flick)"
echo "flick_main_pid=$(systemctl show flick -P MainPID)"
echo "flick_exec=$(systemctl show flick -P ExecStart)"
echo "flick_tty=$(systemctl show flick -P TTYPath)"
echo "flick_tty_reset=$(systemctl show flick -P TTYReset)"
echo "flick_tty_deallocate=$(systemctl show flick -P TTYVTDisallocate)"
echo "flick_restart_policy=$(systemctl show flick -P Restart)"
for service in sshd NetworkManager seatd; do
    printf 'service_%s=%s\n' "$service" "$(systemctl is-active "$service")"
done
booted="$(readlink -f /run/booted-system)"
current="$(readlink -f /run/current-system)"
echo "nixos_booted=$booted"
echo "nixos_current=$current"
[[ "$booted" == "$current" ]] || { echo "BLOCK: NixOS generation changed from boot" >&2; exit 1; }
touch="$(readlink -f /dev/input/by-path/first-touchscreen)"
echo "touchscreen=$touch"
[[ -c "$touch" ]] || { echo "BLOCK: no character touchscreen device" >&2; exit 1; }
# Verify stable hashes of all five separately built artifacts. No chmod, copy, or restart.
dir=/home/alex/lenovo-mvp/builds
while read -r digest filename; do
    file="$dir/$filename"
    [[ -r "$file" && -x "$file" ]] || { echo "BLOCK: missing or non-executable $file" >&2; exit 1; }
    actual="$(sha256sum "$file" | awk '{print $1}')"
    if [[ "$actual" != "$digest" ]]; then
        echo "BLOCK: wrong SHA-256: $file" >&2
        exit 1
    fi
    echo "staged_verified=$filename:$actual"
done <<'HASHES'
ad01f34e4576f0b8d6a8254835884758179df40923cb377564c0fc4c7dc2f7f6 flick-logging-x86_64
34cf5fa26b25b88f749522a92692f9896c301d84ace73a92dec8bf96074a6e38 flick-qml-experimental-x86_64
a049d7b41bcd9939831a94a54e764b437d3c879127ba52670a4d943848b12b2c flick-dmabuf-experimental-x86_64
361d97fcda198e202540298a23455496cabbaaf70a825a58ae85747b11a72f04 flick-qt-egl-experimental-x86_64
4c0d8a75d70f727092522cc82941f12d6421b1b0c44b26e0f7a1a4cbe054006d flick-qt-egl-qml-experimental-x86_64
HASHES
# The Nix-packaged original adds FLICK_ROOT and graphics ABI search paths.
# Candidate wrappers must be pinned too: an ELF hash match alone is NOT
# sufficient to run Flick with the same runtime libraries as the installed
# service. Verify the exact five user-owned, inactive staging launchers.
while read -r digest name; do
    f="$dir/$name"
    [[ -f "$f" && -x "$f" && ! -L "$f" ]] || { echo "BLOCK: missing, non-executable or symlink launcher $f" >&2; exit 1; }
    actual="$(sha256sum "$f" | awk '{print $1}')"
    [[ "$actual" == "$digest" ]] || { echo "BLOCK: modified launcher $name" >&2; exit 1; }
    bash -n "$f"
    echo "launcher_verified=$name:$actual"
done <<'WRAPPERS'
ad3b31e1baaa21d2087140f53fcf88c66f8391041baf0ff0b43d10a392914989 .launch-flick-logging-experimental
5a45a580b0f98623fa88fb76c9343be3b10cd60ebbf5531c731c6353652bb37e .launch-flick-qml-experimental
44a0a028b18513131ad538145d9c4f025ca6c1e995b702bdaad4bd765ffa1077 .launch-flick-dmabuf-experimental
3a5091a4be2b48814526dea0c4e0e72aaade46315422ef1024e61ac17b338776 .launch-flick-qt-egl-experimental
03c4d9c73be4475648feae827d53a31f55d7893c399dd0e99be661448c430e22 .launch-flick-qt-egl-qml-experimental
WRAPPERS
echo "free_disk=$(df -h / | tail -1)"
echo "read_only_preflight=PASS"
echo "physical_access_confirmed=NOT_VERIFIED"
echo "automatic_rollback_tested=NO"
echo "live_activation_performed=NO"
