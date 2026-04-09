# Android Emulator Storage Issues - Solutions Guide

## Quick Diagnosis

If you're seeing storage errors when starting the Android emulator or running apps, try these solutions in order:

## Solution 1: Run the Automated Fix Script (Recommended)

I've created a script that tries multiple cleanup approaches:

```bash
./fix-android-storage.sh
```

This script will:
- Clear all app caches
- Clear system cache partitions
- Clear logs and temporary files
- Show you which packages are taking up space
- Display current storage status

## Solution 2: Alternative ADB Commands

If `pm trim-caches` doesn't work, try these alternatives:

### Clear specific directories
```bash
# Connect to your emulator
DEVICE=$(adb devices | grep "emulator" | awk '{print $1}')

# Clear various cache directories
adb -s $DEVICE shell "rm -rf /data/dalvik-cache/*"
adb -s $DEVICE shell "rm -rf /cache/*"
adb -s $DEVICE shell "rm -rf /data/local/tmp/*"
adb -s $DEVICE shell "rm -rf /data/anr/*"
adb -s $DEVICE shell "rm -rf /data/tombstones/*"

# Clear app-specific caches
adb -s $DEVICE shell "pm list packages" | cut -f 2 -d ":" | while read pkg; do
    adb -s $DEVICE shell "pm clear $pkg" 2>/dev/null
done
```

### Root access method (if needed)
```bash
# Try with root access
adb -s emulator-5554 root
adb -s emulator-5554 shell "rm -rf /data/dalvik-cache/*"
adb -s emulator-5554 unroot
```

## Solution 3: Cold Boot the Emulator

A cold boot clears temporary caches and often resolves storage issues:

```bash
# 1. List available emulators
emulator -list-avds

# 2. Close any running emulators
adb emu kill

# 3. Cold boot with data wipe
emulator -avd YOUR_AVD_NAME -no-snapshot-load -wipe-data &

# Wait for boot to complete, then try your app again
```

## Solution 4: Increase Emulator Storage (Permanent Fix)

1. Open **Android Studio**
2. Go to **Tools → Device Manager** (or AVD Manager)
3. Find your emulator and click **Edit** (pencil icon)
4. Click **Show Advanced Settings**
5. Under **Memory and Storage**:
   - Increase **Internal Storage** to 4096 MB or higher
   - Increase **SD Card** if needed
6. Click **Finish**
7. Restart the emulator

## Solution 5: Create a New AVD

If the above doesn't work, create a fresh emulator:

```bash
# Using Android Studio:
# 1. Tools → Device Manager
# 2. Create Device
# 3. Select a device (e.g., Pixel 8)
# 4. Select a system image (API 35 recommended)
# 5. Show Advanced Settings:
#    - Internal Storage: 4096 MB
#    - SD Card: 512 MB
# 6. Finish

# Or using command line:
avdmanager create avd -n Pixel_8_API_35_Large \
  -k "system-images;android-35;google_apis;arm64-v8a" \
  -d "pixel_8" \
  --sdcard 512M
```

## Solution 6: Clean Build on React Native App

Sometimes the issue is with the app build cache:

```bash
cd repos/mobile-o11y-demo/Mobiles/react-native

# Clean Android build
cd android
./gradlew clean
rm -rf .gradle build app/build
cd ..

# Clean Metro bundler cache
yarn start --reset-cache

# Reinstall app
yarn android
```

## Checking Storage Status

To see current storage usage:

```bash
DEVICE=$(adb devices | grep "emulator" | awk '{print $1}')

# Overall storage
adb -s $DEVICE shell "df -h /data"

# Largest packages
adb -s $DEVICE shell "pm list packages -f" | while read line; do
    pkg=$(echo $line | awk -F'=' '{print $2}')
    size=$(adb -s $DEVICE shell "du -sh /data/data/$pkg 2>/dev/null" | awk '{print $1}')
    [ ! -z "$size" ] && echo "$pkg: $size"
done | sort -rh | head -10
```

## Prevention Tips

1. **Regular cleanup**: Run the fix script periodically
2. **Use larger storage**: Set Internal Storage to at least 4 GB when creating AVDs
3. **Wipe data on boot**: Use `-wipe-data` flag occasionally
4. **Remove unused apps**: Uninstall test apps you're not using
5. **Disable snapshots** if you don't need them: `-no-snapshot-save -no-snapshot-load`

## Troubleshooting

### If nothing works:
1. Delete the AVD completely and create a new one with more storage
2. Check your host machine has enough disk space
3. Verify Android SDK is up to date
4. Restart your computer (sometimes helps with locked files)

### AVD location (to manually delete):
- **macOS/Linux**: `~/.android/avd/`
- **Windows**: `C:\Users\<username>\.android\avd\`

You can delete an AVD folder manually if Android Studio can't remove it.

## Running the React Native Demo

After fixing storage:

```bash
cd repos/mobile-o11y-demo/Mobiles/react-native

# Make sure backend is running
docker run --rm -d -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest

# Start Metro
yarn start

# In another terminal, run Android
yarn android
```

## Need More Help?

- Check emulator logs: `adb -s emulator-5554 logcat`
- Android Studio Event Log: View → Tool Windows → Event Log
- React Native logs: Metro bundler terminal output
