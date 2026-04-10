#!/bin/bash
set -e

# Android Emulator Storage Fix Script
# Fixes installation issues and clears storage

echo "=== Android Emulator Storage Fix ==="
echo ""

# Check if emulator is running
DEVICE=$(adb devices | grep "emulator" | awk '{print $1}')

if [ -z "$DEVICE" ]; then
    echo "❌ No Android emulator detected. Start your emulator first."
    echo ""
    echo "To start an emulator:"
    echo "  emulator -list-avds"
    echo "  emulator -avd <avd_name> &"
    exit 1
fi

echo "✓ Found device: $DEVICE"
echo ""

# Solution 1: Uninstall the QuickPizza app (fixes installation location conflicts)
echo "1️⃣  Uninstalling QuickPizza app..."
timeout 10 adb -s $DEVICE uninstall com.quickpizza 2>/dev/null && echo "✓ App uninstalled" || echo "ℹ️  App not installed or uninstall timed out (skipping)"
echo ""

# Solution 2: Clean local Gradle build (fixes corrupted APK issues)
echo "2️⃣  Cleaning Gradle build cache..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RN_DIR="$SCRIPT_DIR/../react-native"

if [ -d "$RN_DIR/android" ]; then
    cd "$RN_DIR/android"
    ./gradlew clean > /dev/null 2>&1 && echo "✓ Gradle cache cleaned" || echo "⚠️  Gradle clean failed"
    cd - > /dev/null
fi
echo ""

# Solution 3: Clear system cache partitions (with timeout to prevent hanging)
echo "3️⃣  Clearing system cache partitions..."
timeout 10 adb -s $DEVICE shell "rm -rf /data/dalvik-cache/*" 2>/dev/null || true
timeout 10 adb -s $DEVICE shell "rm -rf /cache/*" 2>/dev/null || true
timeout 10 adb -s $DEVICE shell "rm -rf /data/local/tmp/*" 2>/dev/null || true
echo "✓ System caches cleared"
echo ""

# Solution 4: Clear logs (with timeout)
echo "4️⃣  Clearing logs..."
timeout 5 adb -s $DEVICE logcat -c 2>/dev/null || true
timeout 5 adb -s $DEVICE shell "rm -rf /data/anr/*" 2>/dev/null || true
timeout 5 adb -s $DEVICE shell "rm -rf /data/tombstones/*" 2>/dev/null || true
echo "✓ Logs cleared"
echo ""

# Solution 5: Show storage status (with timeout)
echo "5️⃣  Current storage status:"
STORAGE_INFO=$(timeout 5 adb -s $DEVICE shell "df -h /data" 2>/dev/null | grep -v "Filesystem" || echo "Unable to check storage")
echo "$STORAGE_INFO"

if echo "$STORAGE_INFO" | grep -q "%"; then
    USAGE=$(echo "$STORAGE_INFO" | awk '{print $5}' | sed 's/%//' | head -1)
    if [ ! -z "$USAGE" ] && [ "$USAGE" -gt 90 ] 2>/dev/null; then
        echo ""
        echo "⚠️  WARNING: Storage is ${USAGE}% full!"
        echo "   You may need to wipe emulator data or create a new AVD with more storage."
    fi
fi
echo ""

echo "=== Done! ==="
echo ""
echo "You can now run: yarn android"
echo ""
echo "If you still have storage issues, try:"
echo "  • Wipe emulator: emulator -avd <name> -wipe-data"
echo "  • Increase storage: Android Studio → Device Manager → Edit AVD → Advanced → Internal Storage (4096 MB)"
echo "  • Create new AVD with more storage"
