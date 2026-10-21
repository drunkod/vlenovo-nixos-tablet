#!/usr/bin/env bash
# MacBook-only follow-through: native CI build -> checked Nix store -> tablet staging.
# NO remote profile/bootloader/screen changes. Independently notify user on readiness.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
COMMON="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
BASE="$(dirname "$COMMON")/.local/archives"
LOG="$BASE/gen59-wpe-native-followthrough.log"
LOCK="$BASE/gen59-wpe-native-followthrough.lock"
READY="$BASE/gen59-wpe-staged-ready.txt"
FAIL="$BASE/gen59-wpe-followthrough-failed.txt"
RUN=39616428062
mkdir -p "$BASE"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "Another verified staging process owns $LOCK"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null || :' EXIT
printf 'GEN59_NATIVE_FOLLOWTHROUGH_START %s\n' "$(date -u +%FT%TZ)" >> "$LOG"
while true; do
  status="$(gh run view "$RUN" -R drunkod/vlenovo-nixos-tablet --json status --jq '.status' 2>/dev/null || echo unknown)"
  printf '%s CI_STATUS %s\n' "$(date -u +%FT%TZ)" "$status" >> "$LOG"
  if [ "$status" = completed ]; then break; fi
  sleep 120
done
conclusion="$(gh run view "$RUN" -R drunkod/vlenovo-nixos-tablet --json conclusion --jq '.conclusion')"
if [ "$conclusion" != success ]; then
  printf 'CI_RUN_%s_FAILED_%s\n' "$RUN" "$conclusion" | tee "$FAIL" >> "$LOG"
  exit 1
fi
echo "NATIVE_CI_SUCCEEDED $(date -u +%FT%TZ)" >> "$LOG"
if "$HERE/continue-gen59-from-actions.sh" all >> "$LOG" 2>&1; then
  echo "GEN59_IMAGE_STAGED_BUT_NOT_ACTIVATED $(date -u +%FT%TZ)" | tee "$READY" >> "$LOG"
  tail -12 "$LOG"
else
  code=$?
  echo "GEN59_FOLLOWTHROUGH_ERROR_$code $(date -u +%FT%TZ)" | tee "$FAIL" >> "$LOG"
  tail -40 "$LOG" >&2
  exit "$code"
fi
