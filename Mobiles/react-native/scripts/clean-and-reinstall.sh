#!/bin/bash
set -e

# Clean and Reinstall Android App
# Complete cleanup for React Native Android installation issues
#
# Usage:
#   ./scripts/clean-and-reinstall.sh
#   ./scripts/clean-and-reinstall.sh --wipe-emulator
#   ./scripts/clean-and-reinstall.sh --wipe-emulator --avd Pixel_9_API_36
# When multiple AVDs exist, pass --avd or set ANDROID_AVD.

WIPE_EMULATOR=0
AVD_CLI=""

usage() {
  cat <<'USAGE'
Clean Gradle/Metro caches and optionally wipe Android emulator userdata.

  ./scripts/clean-and-reinstall.sh
  ./scripts/clean-and-reinstall.sh --wipe-emulator
  ./scripts/clean-and-reinstall.sh --wipe-emulator --avd YOUR_AVD_NAME

When several AVDs exist, pass --avd or set ANDROID_AVD. For --wipe-emulator the
script stops adb-visible emulators, then starts the chosen AVD with -wipe-data in
the background (log: /tmp/emulator-wipe-data.log).

  -h, --help   Show this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --wipe-emulator)
      WIPE_EMULATOR=1
      shift
      ;;
    --avd)
      if [ -z "${2:-}" ]; then
        echo "❌ --avd requires a name (see: emulator -list-avds)" >&2
        exit 1
      fi
      AVD_CLI="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1 (try --help)" >&2
      exit 1
      ;;
  esac
done

resolve_android_sdk() {
  if [ -n "${ANDROID_SDK_ROOT:-}" ] && [ -d "${ANDROID_SDK_ROOT}/emulator" ]; then
    printf '%s' "$ANDROID_SDK_ROOT"
  elif [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/emulator" ]; then
    printf '%s' "$ANDROID_HOME"
  elif [ -d "$HOME/Library/Android/sdk/emulator" ]; then
    printf '%s' "$HOME/Library/Android/sdk"
  else
    printf ''
  fi
}

kill_adb_emulators() {
  local serial
  for serial in $(adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator/ { print $1 }'); do
    echo "   Stopping $serial ..."
    adb -s "$serial" emu kill 2>/dev/null || true
  done
  sleep 2
}

wipe_emulator_userdata_cli() {
  local sdk emu chosen line

  sdk="$(resolve_android_sdk)"
  if [ -z "$sdk" ]; then
    echo "❌ Android SDK not found. Set ANDROID_SDK_ROOT or ANDROID_HOME, or install to ~/Library/Android/sdk"
    return 1
  fi
  emu="$sdk/emulator/emulator"
  if [ ! -x "$emu" ]; then
    echo "❌ Emulator binary not found at: $emu"
    return 1
  fi

  export PATH="$sdk/platform-tools:$PATH"

  chosen=""
  if [ -n "$AVD_CLI" ]; then
    chosen="$AVD_CLI"
  elif [ -n "${ANDROID_AVD:-}" ]; then
    chosen="$ANDROID_AVD"
  else
    local count=0
    local first=""
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      count=$((count + 1))
      [ $count -eq 1 ] && first="$line"
    done <<EOF
$( "$emu" -list-avds 2>/dev/null || true )
EOF
    if [ "$count" -eq 0 ]; then
      echo "❌ No AVDs found. Create one in Android Studio Device Manager, or run:"
      echo "   $emu -list-avds"
      return 1
    elif [ "$count" -eq 1 ]; then
      chosen="$first"
      echo "ℹ️  Single AVD found, using: $chosen"
    else
      echo "❌ Multiple AVDs; pick one:"
      "$emu" -list-avds 2>/dev/null || true
      echo "   Re-run with: --wipe-emulator --avd <name>"
      echo "   Or set ANDROID_AVD=<name>"
      return 1
    fi
  fi

  if ! "$emu" -list-avds 2>/dev/null | grep -Fxq "$chosen"; then
    echo "❌ AVD not found: $chosen"
    echo "   Available:"
    "$emu" -list-avds 2>/dev/null || true
    return 1
  fi

  echo ""
  echo "6️⃣  Wipe emulator userdata (CLI) ..."
  echo "   AVD: $chosen"
  kill_adb_emulators

  # -wipe-data clears userdata on this boot; -no-snapshot-load avoids stale quick-boot state.
  echo "   Starting emulator in background (wipe runs on startup) ..."
  (
    cd "$sdk" || exit 1
    nohup "$emu" -avd "$chosen" -wipe-data -no-snapshot-load >>/tmp/emulator-wipe-data.log 2>&1 &
    echo "$!" >/tmp/emulator-wipe-data.pid
  )
  echo "✓ Emulator launch requested (PID file: /tmp/emulator-wipe-data.pid, log: /tmp/emulator-wipe-data.log)"
  echo "   Wait until the device shows as \"device\" in adb devices, then: yarn android"
}

echo "=== React Native Android: Clean & Reinstall ==="
echo ""

# Step 1: Stop Metro if running
echo "1️⃣  Stopping Metro bundler..."
METRO_PID=$(lsof -ti :8081 2>/dev/null || true)
if [ ! -z "$METRO_PID" ]; then
    kill $METRO_PID 2>/dev/null || true
    sleep 1
    echo "✓ Metro stopped (PID: $METRO_PID)"
else
    echo "ℹ️  Metro not running"
fi
echo ""

# Step 2: Run parent storage fix script
echo "2️⃣  Running Android storage cleanup..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_SCRIPT="$SCRIPT_DIR/../../scripts/fix-android-storage.sh"

if [ -f "$PARENT_SCRIPT" ]; then
  if [ "$WIPE_EMULATOR" -eq 1 ]; then
    if command -v adb >/dev/null 2>&1 && adb devices 2>/dev/null | grep -qE '^emulator[^[:space:]]+[[:space:]]+device$'; then
      bash "$PARENT_SCRIPT"
    else
      echo "ℹ️  No running emulator — skipping adb storage cleanup (userdata will reset at end with --wipe-emulator)."
    fi
  else
    bash "$PARENT_SCRIPT"
  fi
else
    echo "⚠️  Parent storage script not found at: $PARENT_SCRIPT"
    echo "   Skipping storage cleanup..."
fi
echo ""

# Step 3: Clean Gradle build
echo "3️⃣  Cleaning Gradle build..."
cd "$SCRIPT_DIR/../android"
./gradlew clean > /dev/null 2>&1 && echo "✓ Gradle cleaned" || echo "⚠️  Gradle clean failed"
cd - > /dev/null
echo ""

# Step 4: Clean Metro cache
echo "4️⃣  Cleaning Metro bundler cache..."
rm -rf /tmp/metro-* 2>/dev/null || true
rm -rf /tmp/react-* 2>/dev/null || true
rm -rf /tmp/haste-map-* 2>/dev/null || true
echo "✓ Metro cache cleaned"
echo ""

# Step 5: Reinstall node_modules for local SDK changes
echo "5️⃣  Reinstalling @grafana packages (for local SDK changes)..."
cd "$SCRIPT_DIR/.."
rm -rf node_modules/@grafana 2>/dev/null || true
corepack enable
yarn install --immutable 2>&1 | grep -E "(Done|error|YN0000)" || true
echo ""

echo "=== Cleanup Complete! ==="
echo ""
echo "Now run these commands in separate terminals:"
echo ""
echo "Terminal 1 - Start Metro:"
echo "  cd Mobiles/react-native"
echo "  yarn start"
echo ""
echo "Terminal 2 - Run Android:"
echo "  cd Mobiles/react-native"
echo "  yarn android"
echo ""

if [ "$WIPE_EMULATOR" -eq 1 ]; then
  wipe_emulator_userdata_cli
fi
