#!/bin/bash

# Script to wait for iOS Simulator to be ready
# Based on run-ios.sh logic

cd "$(dirname "$0")/.."

echo "Waiting for iOS Simulator to be ready..."
MAX_WAIT=60

for i in $(seq 1 $MAX_WAIT); do
    if flutter devices | grep -q ios; then
        echo "iOS Simulator is ready!"
        flutter devices | grep ios
        exit 0
    fi
    
    if [ $((i % 10)) -eq 0 ]; then
        echo "Still waiting... ($i/$MAX_WAIT seconds)"
        echo "Current devices:"
        flutter devices
    fi
    
    sleep 1
done

echo "Warning: Could not detect iOS device after $MAX_WAIT seconds, but proceeding anyway..."
flutter devices
exit 0

