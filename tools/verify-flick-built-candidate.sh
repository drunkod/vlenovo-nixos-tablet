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
    dmabuf)
        attr="packages.x86_64-linux.flick-dmabuf-experimental"
        name="flick-dmabuf-experimental-x86_64"
        ;;
    qt-egl)
        attr="packages.x86_64-linux.flick-qt-egl-experimental"
        name="flick-qt-egl-experimental-x86_64"
        ;;
    *)
        echo "Usage: $0 {logging|qml|dmabuf|qt-egl} [--stage]" >&2
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

    # The tablet already has the base unwrapped Flick runtime closure. Reject a
    # new candidate that would require additional store paths before copying it.
    known_good=/nix/store/im04hvdj3p8i7ncywpb8accldk2bnd2k-flick-unstable-2026-01-04
    new_refs="$(mktemp)"
    known_refs="$(mktemp)"
    trap 'rm -f "$new_refs" "$known_refs"' EXIT
    docker --context "$CONTEXT" exec "$CONTAINER" nix-store -q --references "$out" | sort > "$new_refs"
    ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
        "nix-store -q --references '$known_good'" | sort > "$known_refs"
    if ! diff -u "$known_refs" "$new_refs"; then
        echo "Runtime Nix store references differ; closure transfer/review required" >&2
        exit 1
    fi
    echo "tablet_runtime_refs=MATCH_KNOWN_GOOD"
    ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo "mkdir -p '$TABLET_STAGE'"
    # A prior staging copy can be read-only. Avoid overwriting its inode and
    # upload to an unprivileged temporary file only when content differs.
    tablet_sha="$(ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
        "test -f '$TABLET_STAGE/$name' && sha256sum '$TABLET_STAGE/$name' || true" | awk '{print $1}')"
    if [[ "$tablet_sha" != "$sha" ]]; then
        remote_tmp="$(ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
            "mktemp '$TABLET_STAGE/.$name.XXXXXXXX'")"
        if ! scp -q -F "$SSH_CONFIG" "$local_bin" "vlenovo:$remote_tmp"; then
            ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo "rm -f '$remote_tmp'"
            echo "Failed to upload staged candidate" >&2
            exit 1
        fi
        tmp_sha="$(ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
            "sha256sum '$remote_tmp'" | awk '{print $1}')"
        if [[ "$tmp_sha" != "$sha" ]]; then
            ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo "rm -f '$remote_tmp'"
            echo "ERROR: tablet temporary file SHA-256 mismatch" >&2
            exit 1
        fi
        ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
            "chmod 755 '$remote_tmp' && mv -f '$remote_tmp' '$TABLET_STAGE/$name'"
        tablet_sha="$(ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
            "sha256sum '$TABLET_STAGE/$name'" | awk '{print $1}')"
    fi
    if [[ "$tablet_sha" != "$sha" ]]; then
        echo "ERROR: staged binary SHA-256 mismatch" >&2
        exit 1
    fi
    echo "tablet_sha256=$tablet_sha"
    ssh -F "$SSH_CONFIG" -o BatchMode=yes vlenovo \
        "'$TABLET_STAGE/$name' --help >/dev/null && systemctl is-active flick sshd NetworkManager seatd"
    echo "staged_only=$TABLET_STAGE/$name"
    echo "active_compositor=UNCHANGED"
fi
