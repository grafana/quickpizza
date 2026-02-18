#!/usr/bin/env bash
set -euo pipefail

SCHEME="QuickPizzaIos"
PROJECT="QuickPizzaIos.xcodeproj"
BUNDLE_ID="com.grafana.QuickPizzaIos"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVICE=""

usage() {
    echo "Usage: $0 [--device <simulator name>]"
    echo ""
    echo "Options:"
    echo "  --device <name>   Simulator device name (e.g. 'iPhone 17 Pro')"
    echo "                    Defaults to first available iPhone simulator."
    echo ""
    echo "Examples:"
    echo "  $0"
    echo "  $0 --device 'iPhone 17 Pro'"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --device) DEVICE="$2"; shift 2 ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

auto_detect_device() {
    xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime in sorted(data.get('devices', {}).keys(), reverse=True):
    for d in data['devices'][runtime]:
        if d.get('isAvailable') and 'iPhone' in d.get('name', ''):
            print(d['name'])
            sys.exit(0)
sys.exit(1)
"
}

if [[ -z "$DEVICE" ]]; then
    echo "==> Auto-detecting simulator..."
    DEVICE=$(auto_detect_device) || { echo "ERROR: No available iPhone simulator found."; exit 1; }
fi
echo "==> Using simulator: $DEVICE"

echo "==> Building $SCHEME for simulator..."
xcodebuild \
    -project "$PROJECT_DIR/$PROJECT" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -derivedDataPath "$PROJECT_DIR/DerivedData" \
    build 2>&1 | tail -20

APP_PATH=$(find "$PROJECT_DIR/DerivedData/Build/Products" -name "*.app" -type d | head -1)
if [[ -z "$APP_PATH" ]]; then
    echo "ERROR: Could not find .app bundle in DerivedData."
    exit 1
fi
echo "==> Found app: $APP_PATH"

BOOT_STATE=$(xcrun simctl list devices -j 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('name') == '$DEVICE' and d.get('isAvailable'):
            print(d.get('state', 'Unknown'))
            sys.exit(0)
print('Unknown')
")

if [[ "$BOOT_STATE" != "Booted" ]]; then
    echo "==> Booting simulator '$DEVICE'..."
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    open -a Simulator
    sleep 2
else
    echo "==> Simulator '$DEVICE' already booted."
fi

echo "==> Installing app..."
xcrun simctl install booted "$APP_PATH"

echo "==> Launching app..."
xcrun simctl launch booted "$BUNDLE_ID"

echo "==> Streaming logs (Ctrl+C to stop)..."
echo "    (Showing logs from subsystem: $BUNDLE_ID)"
xcrun simctl spawn booted log stream \
    --predicate "subsystem == \"$BUNDLE_ID\"" \
    --level debug \
    --style compact
