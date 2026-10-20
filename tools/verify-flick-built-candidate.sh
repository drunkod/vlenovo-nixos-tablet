#!/usr/bin/env bash
# Safely verify a Mac-hosted x86_64-linux Flick binary; optionally stage it.
# This script never starts/stops a compositor or activates a NixOS generation.
# Usage: tools/verify-flick-built-candidate.sh logging [--stage]
#        tools/verify-flick-built-candidate.sh qml [--stage]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTEXT="colima-vlenovo-flick-build"
CONTAINER="vlenovo-flick-nixbuild"
SSH_CONFIG="${VLENOVO_SSH_CONFIG:-$HOME/.ssh/vlenovo_config}"
STAGE_DIR="$ROOT/.flick-nix-candidate"
TABLET_STAGE="/home/alex/lenovo-mvp/builds"

variant="${1:-}"
action="${2:-}"
case "$variant" in
    logging)
        attr="packages.x86_64-linux.flick.unwrapped"
        name="flick-logging-x86_64"
        ;;
    qml)
        attr="packages.x86_64-linux.flick-qml-experimental"
        name="flick-qml-experimental-x86_64"
        ;;
    *)
        echo "Usage: $0 {logging|qml} [--stage]" >&2
        exit 2
        ;;
esac
if [[ -n "$action" && "$action" != "--stage" ]]; then
    echo "Only the optional --stage argument is supported" >&2
    exit 2
fi

nix=(docker --context "$CONTEXT" exec "$CONTAINER"
  nix --extra-experimental-features "nix-command flakes" --option sandbox false)
out="$("${nix[@]}" eval --raw "path:/work#$attr.outPath")"
if [[ ! "$out" =~ ^/nix/store/[0-9a-z]+-flick-unstable-2026-01-04$ ]]; then
    echo "Unrecognised Nix store output: $out" >&2
    exit 1
fi
docker --context "$CONTEXT" exec "$CONTAINER" nix-store --verify-path "$out"
mkdir -p "$STAGE_DIR"
local_bin="$STAGE_DIR/$name"
docker --context "$CONTEXT" cp "$CONTAINER:$out/bin/flick" "$local_bin"
chmod +x "$local_bin"
file "$local_bin"
if ! file "$local_bin" | grep -q 'ELF 64-bit.*x86-64'; then
    echo "Not a Linux x86-64 ELF binary" >&2
    exit 1
fi
sha="$(shasum -a 256 "$local_bin" | awk '{print $1}')"
printf 'variant=%s\nstore_path=%s\nsha256=%s\n' "$variant" "$out" "$sha"
docker --context "$CONTEXT" exec "$CONTAINER" "$out/bin/flick" --help | head -14

if [[ "$action" == "--stage" ]]; then
    test -f "$SSH_CONFIG" || { echo "Missing SSH config $SSH_CONFIG" >&2; exit 1; }
    ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo "mkdir -p '$TABLET_STAGE'"
    scp -q -F "$SSH_CONFIG" "$local_bin" "vlenovo:$TABLET_STAGE/$name"
    tablet_sha="$(ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo "sha256sum '$TABLET_STAGE/$name'" | awk '{print $1}')"
    if [[ "$tablet_sha" != "$sha" ]]; then
        echo "ERROR: tablet SHA-256 mismatch" >&2
        exit 1
    fi
    echo "tablet_sha256=$tablet_sha"
    ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
        "'$TABLET_STAGE/$name' --help >/dev/null && systemctl is-active flick sshd NetworkManager seatd"
    echo "staged_only=$TABLET_STAGE/$name"
    echo "active_compositor=UNCHANGED"
fi
