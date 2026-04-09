#!/bin/bash

# Android Emulator Storage Fix Script
# Multiple solutions for resolving storage issues

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

# Solution 1: Clear app data cache
echo "1️⃣  Clearing app caches..."
adb -s $DEVICE shell "pm list packages" | cut -f 2 -d ":" | while read pkg; do
    adb -s $DEVICE shell "pm clear $pkg" 2>/dev/null
done
echo "✓ App caches cleared"
echo ""

# Solution 2: Clear system cache partitions
echo "2️⃣  Clearing system cache partitions..."
adb -s $DEVICE shell "rm -rf /data/dalvik-cache/*" 2>/dev/null
adb -s $DEVICE shell "rm -rf /cache/*" 2>/dev/null
adb -s $DEVICE shell "rm -rf /data/local/tmp/*" 2>/dev/null
echo "✓ System caches cleared"
echo ""

# Solution 3: Clear logs
echo "3️⃣  Clearing logs..."
adb -s $DEVICE logcat -c
adb -s $DEVICE shell "rm -rf /data/anr/*" 2>/dev/null
adb -s $DEVICE shell "rm -rf /data/tombstones/*" 2>/dev/null
echo "✓ Logs cleared"
echo ""

# Solution 4: Uninstall unused apps
echo "4️⃣  Finding large packages..."
adb -s $DEVICE shell "pm list packages -f" | while read line; do
    pkg=$(echo $line | awk -F'=' '{print $2}')
    size=$(adb -s $DEVICE shell "du -sh /data/data/$pkg 2>/dev/null" | awk '{print $1}')
    [ ! -z "$size" ] && echo "  $pkg: $size"
done | sort -rh | head -10
echo ""

# Show storage status
echo "5️⃣  Current storage status:"
adb -s $DEVICE shell "df -h /data" | grep -v "Filesystem"
echo ""

echo "=== Done! ==="
echo ""
echo "If you still have issues, try:"
echo "  • Increase emulator storage: Android Studio → AVD Manager → Edit AVD → Advanced Settings → Internal Storage"
echo "  • Cold boot: emulator -avd <name> -no-snapshot-load -wipe-data"
echo "  • Create a new AVD with more storage"
