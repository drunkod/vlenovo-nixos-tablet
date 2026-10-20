#!/usr/bin/env bash
set -u

STATE_DIR="${FLICK_STATE_DIR:-$HOME/.local/state/flick}"
FLICK_ROOT="${FLICK_ROOT:?FLICK_ROOT is required}"
LOG_FILE="$STATE_DIR/qml_lockscreen.log"
SETTINGS_CTL="$FLICK_ROOT/apps/settings/flick-settings-ctl"
QML_FILE="$FLICK_ROOT/apps/lockscreen/main.qml"
RUNTIME_IMPORT_ROOT="$STATE_DIR/qml"
RUNTIME_MODULE="$RUNTIME_IMPORT_ROOT/FlickRuntime"
VERIFY_RESULT="$STATE_DIR/verify_result"

mkdir -p "$STATE_DIR" "$RUNTIME_MODULE"
: > "$LOG_FILE"

cat > "$RUNTIME_MODULE/qmldir" <<'QMLDIR_EOF'
module FlickRuntime
singleton Runtime 1.0 Runtime.qml
QMLDIR_EOF

qml_state="${STATE_DIR//\\/\\\\}"
qml_state="${qml_state//\"/\\\"}"
cat > "$RUNTIME_MODULE/Runtime.qml" <<RUNTIME_EOF
pragma Singleton
import QtQuick 2.15
QtObject {
    readonly property string stateDir: "$qml_state"
}
RUNTIME_EOF

echo "Starting QML lockscreen, state_dir=$STATE_DIR" >> "$LOG_FILE"
echo "QML_FILE=$QML_FILE" >> "$LOG_FILE"

export QML_XHR_ALLOW_FILE_READ=1
export QT_LOGGING_RULES="*.debug=false;qt.qpa.*=false;qt.accessibility.*=false"
export QT_MESSAGE_PATTERN=""
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_WAYLAND_CLIENT_BUFFER_INTEGRATION=wayland-egl
export QML2_IMPORT_PATH="$RUNTIME_IMPORT_ROOT${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"

rm -f "$VERIFY_RESULT"

verify_pattern() {
    local pattern="$1"
    echo "Verifying pattern: $pattern" >> "$LOG_FILE"
    rm -f "$VERIFY_RESULT"
    local result
    result=$("$SETTINGS_CTL" lock verify-pattern "$pattern" 2>/dev/null || true)
    echo "Verification result: $result" >> "$LOG_FILE"
    printf '%s\n' "$result" > "$VERIFY_RESULT"
}

exit_code_file=$(mktemp)
trap 'rm -f "$exit_code_file" "$VERIFY_RESULT"' EXIT

while IFS= read -r line; do
    echo "$line" >> "$LOG_FILE"
    if [[ "$line" == *"VERIFY_PATTERN:"* ]]; then
        pattern="${line#*VERIFY_PATTERN:}"
        verify_pattern "$pattern"
    fi
done < <(@qmlscene@ "$QML_FILE" 2>&1; echo $? > "$exit_code_file")

exit_code=$(cat "$exit_code_file")
echo "QML lockscreen exited with code $exit_code" >> "$LOG_FILE"

if [ "$exit_code" -eq 0 ]; then
    signal_file="$STATE_DIR/unlock_signal"
    echo "Creating unlock signal: $signal_file" >> "$LOG_FILE"
    touch "$signal_file"
fi

exit "$exit_code"
