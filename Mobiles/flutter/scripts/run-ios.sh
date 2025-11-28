#!/bin/bash

# Script to run Flutter app on iOS simulator
# Make sure iOS simulator is available

cd "$(dirname "$0")/.."

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
flutter run -d "$IOS_DEVICE"

