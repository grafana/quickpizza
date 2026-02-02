#!/bin/bash

# Script to run Flutter app on iOS simulator
# Make sure iOS simulator is available

cd "$(dirname "$0")/.."

# ============================================
# Config file check
# ============================================
CONFIG_FILE="config.json"
CONFIG_EXAMPLE="config.json.example"

if [ ! -f "$CONFIG_FILE" ]; then
    echo ""
    echo "⚠️  WARNING: $CONFIG_FILE not found!"
    echo ""
    
    if [ -f "$CONFIG_EXAMPLE" ]; then
        echo "Creating $CONFIG_FILE from $CONFIG_EXAMPLE..."
        cp "$CONFIG_EXAMPLE" "$CONFIG_FILE"
        echo ""
        echo "📝 Please edit $CONFIG_FILE with your actual values:"
        echo "   - FARO_COLLECTOR_URL: Your Grafana Faro collector URL"
        echo "   - BASE_URL: Backend API URL (optional, has platform defaults)"
        echo "   - PORT: Backend port (optional, defaults to 3333)"
        echo ""
        echo "Then run this script again."
        exit 1
    else
        echo "❌ ERROR: $CONFIG_EXAMPLE not found either!"
        echo "Please create $CONFIG_FILE manually with the following structure:"
        echo '{'
        echo '  "FARO_COLLECTOR_URL": "https://your-collector-url",'
        echo '  "BASE_URL": "",'
        echo '  "PORT": "3333"'
        echo '}'
        exit 1
    fi
fi

echo "✅ Using config from $CONFIG_FILE"

# ============================================
# iOS device detection
# ============================================
echo "Checking for iOS devices..."
if ! flutter devices | grep -q ios; then
    echo "No iOS device found. Opening iOS Simulator..."
    open -a Simulator
    ./scripts/wait-for-ios-simulator.sh
fi

echo "Finding iOS device..."
# Extract the first iOS device ID from flutter devices output
# Format: "Device Name • UUID • ios • ..."
# Use awk to split by bullet character and get the UUID (2nd field)
IOS_DEVICE=$(flutter devices 2>/dev/null | grep "• ios" | head -n 1 | awk -F '•' '{print $2}' | xargs)

if [ -z "$IOS_DEVICE" ]; then
    echo "Error: Could not find iOS device ID"
    echo "Available devices:"
    flutter devices
    exit 1
fi

echo "Running Flutter app on iOS device: $IOS_DEVICE"
flutter run -d "$IOS_DEVICE" --dart-define-from-file="$CONFIG_FILE"
