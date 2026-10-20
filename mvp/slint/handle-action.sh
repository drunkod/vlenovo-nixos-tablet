#!/bin/sh
# Read-only callback bridge for touch verification; does not execute user commands.
set -eu
action="${1:-}"
case "$action" in
  status|assist|network) ;;
  *) echo "Ignoring unexpected action" >&2; exit 2 ;;
esac
D=/home/alex/lenovo-mvp
stamp="$(date -u +%FT%TZ)"
memory="$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)"
wifi="$(cat /sys/class/net/wlan0/operstate 2>/dev/null || echo unknown)"
printf '%s\taction=%s\tmem_available_kib=%s\twlan0=%s\n' "$stamp" "$action" "$memory" "$wifi" >> "$D/touch-events.tsv"
