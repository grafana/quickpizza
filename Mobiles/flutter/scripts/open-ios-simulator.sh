#!/bin/bash

# Script to open iOS Simulator
# Based on run-ios.sh logic

cd "$(dirname "$0")/.."

echo "Checking for iOS devices..."
flutter devices | grep ios

if [ $? -ne 0 ]; then
    echo "No iOS device found. Opening iOS Simulator..."
    open -a Simulator
    echo "Waiting for simulator to start..."
    sleep 5
else
    echo "iOS Simulator already available"
fi

