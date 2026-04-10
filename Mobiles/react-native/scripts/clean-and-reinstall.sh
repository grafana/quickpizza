#!/bin/bash
set -e

# Clean and Reinstall Android App
# Complete cleanup for React Native Android installation issues

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
    bash "$PARENT_SCRIPT"
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
yarn install --force 2>&1 | grep -E "(Done|error)" || true
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
