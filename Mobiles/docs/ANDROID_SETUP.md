# Android Setup Guide

Simple steps to set up Android development and run the app on Android Emulator.

## Setup Steps

### 1. Install Android Studio
- Download from: https://developer.android.com/studio
- Install and complete the setup wizard
- Choose "Standard" installation (it will download Android SDK automatically)

### 2. Install SDK Components
- Open Android Studio
- Go to **Settings > Android SDK** (or **Preferences > Android SDK** on macOS)
- **SDK Platforms tab:** Check at least one Android version (e.g., Android 13.0)
- **SDK Tools tab:** Ensure these are checked:
  - ✅ Android SDK Build-Tools
  - ✅ Android SDK Platform-Tools
  - ✅ Android Emulator
  - ✅ Android SDK Command-line Tools (latest)
- Click **Apply** and wait for installation

### 3. Accept Android Licenses
```bash
flutter doctor --android-licenses
```
Type `y` and press Enter for each license.

### 4. Create Android Virtual Device (AVD)
- In Android Studio: **Tools > Device Manager**
- Click **Create Device** (+ button)
- Choose a device (e.g., Pixel 5, Pixel 6)
- Select an Android version (download if needed)
- Click **Finish**

### 5. Verify Setup
```bash
cd Mobiles/flutter
flutter doctor
```
You should see ✓ for Android toolchain.

---

## Open Android Emulator

**Option 1: From Android Studio**
- Open Android Studio
- Go to **Tools > Device Manager**
- Click the **Play** button (▶️) next to your AVD

**Option 2: From Command Line**
```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>
```

---

## Run the App

### Quick Start (Recommended)

**Easiest way - automatically opens emulator and runs the app:**
```bash
cd Mobiles/flutter
./scripts/run-android.sh
```

This script will:
- Check if an Android emulator is running
- Launch an emulator if needed
- Wait for it to be ready
- Run the app automatically

### Manual Steps

1. **Make sure the emulator is running** (you should see the Android home screen)

2. **Run the app:**
```bash
cd Mobiles/flutter
flutter run
```

Or specify Android explicitly:
```bash
flutter run -d android
```

**Using VS Code:**
- Press **F5**
- Select "Flutter: Run (Android)"

---

## Quick Troubleshooting

**Emulator not showing in `flutter devices`:**
- Make sure emulator is running and fully booted
- Wait a few seconds and try `flutter devices` again

**Android SDK not found:**
```bash
# Find your SDK path in Android Studio: Settings > Android SDK
# Then configure Flutter:
flutter config --android-sdk ~/Library/Android/sdk
```

**Licenses not accepted:**
```bash
flutter doctor --android-licenses
```

**Need more help?**
- Run diagnostics: `flutter doctor -v`
