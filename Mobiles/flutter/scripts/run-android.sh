#!/bin/bash

# Script to run Flutter app on Android emulator
# Ensures the app runs on the emulator that was just launched

cd "$(dirname "$0")/.."

echo "Checking for Android devices..."
# Extract device IDs (the field after the first bullet point, e.g., "emulator-5554")
INITIAL_DEVICES=$(flutter devices 2>&1 | grep android | awk -F'•' '{print $2}' | awk '{print $1}' | tr -d ' ' || echo "")

if [ -z "$INITIAL_DEVICES" ]; then
    echo "No Android device found. Starting Android emulator..."
    EMULATOR_NAME=$(flutter emulators | grep android | head -1 | awk '{print $1}')
    
    if [ -z "$EMULATOR_NAME" ]; then
        echo "Error: No Android emulator found. Please create an emulator first."
        exit 1
    fi
    
    echo "Launching emulator: $EMULATOR_NAME"
    flutter emulators --launch "$EMULATOR_NAME"
    echo "Waiting for emulator to start..."
    
    # Wait for the new emulator to appear
    MAX_WAIT=60
    NEW_DEVICE_ID=""
    
    for i in $(seq 1 $MAX_WAIT); do
        # Extract device IDs (the field after the first bullet point)
        CURRENT_DEVICES=$(flutter devices 2>&1 | grep android | awk -F'•' '{print $2}' | awk '{print $1}' | tr -d ' ' || echo "")
        
        # Find the new device (one that wasn't in initial list)
        if [ ! -z "$CURRENT_DEVICES" ]; then
            for device in $(echo "$CURRENT_DEVICES"); do
                if [ -z "$INITIAL_DEVICES" ] || ! echo "$INITIAL_DEVICES" | grep -q "$device"; then
                    NEW_DEVICE_ID="$device"
                    break
                fi
            done
        fi
        
        if [ ! -z "$NEW_DEVICE_ID" ]; then
            echo "Emulator ready! Device ID: $NEW_DEVICE_ID"
            break
        fi
        
        if [ $((i % 10)) -eq 0 ]; then
            echo "Still waiting for emulator... ($i/$MAX_WAIT seconds)"
        fi
        sleep 1
    done
    
    if [ -z "$NEW_DEVICE_ID" ]; then
        # Fallback: use first available device
        NEW_DEVICE_ID=$(flutter devices 2>&1 | grep android | head -1 | awk -F'•' '{print $2}' | awk '{print $1}' | tr -d ' ')
        if [ -z "$NEW_DEVICE_ID" ]; then
            echo "Error: Could not find Android device after launching emulator"
            exit 1
        fi
        echo "Using available device: $NEW_DEVICE_ID"
    fi
    
    DEVICE_ID="$NEW_DEVICE_ID"
else
    # Device already available, use the first one
    DEVICE_ID=$(echo "$INITIAL_DEVICES" | head -1 | awk '{print $1}')
    echo "Using existing device: $DEVICE_ID"
fi

echo "Running Flutter app on device: $DEVICE_ID"
flutter run -d "$DEVICE_ID"

