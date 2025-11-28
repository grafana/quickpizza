# iOS Setup Guide

Simple steps to set up iOS development and run the app on iOS Simulator.

## Setup Steps

### 1. Install Xcode
- Open App Store
- Search for "Xcode" and install it
- Wait for installation to complete (~15GB, may take 30-60 minutes)

### 2. Configure Xcode
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
sudo xcodebuild -runFirstLaunch
```

### 3. Install CocoaPods
```bash
brew install cocoapods
```

### 4. Download iOS Simulator Runtime
- Open Xcode
- Go to **Xcode > Settings > Platforms**
- Download an iOS version (e.g., iOS 17.0 or latest)

### 5. Verify Setup
```bash
cd Mobiles/flutter
flutter doctor
```
You should see ✓ for Xcode and CocoaPods.

---

## Open iOS Simulator

**Option 1: Using Command Line**
```bash
open -a Simulator
```

**Option 2: Using Xcode**
- Open Xcode
- Go to **Xcode > Open Developer Tool > Simulator**

**Option 3: Boot Specific Simulator**
```bash
xcrun simctl boot "iPhone 17 Pro"
open -a Simulator
```

---

## Run the App

### Quick Start (Recommended)

**Easiest way - automatically opens simulator and runs the app:**
```bash
cd Mobiles/flutter
./scripts/run-ios.sh
```

This script will:
- Check if an iOS simulator is running
- Open the simulator if needed
- Wait for it to be ready
- Run the app automatically

### Manual Steps

1. **Make sure the simulator is running** (you should see the iOS home screen)

2. **Run the app:**
```bash
cd Mobiles/flutter
flutter run
```

Or specify iOS explicitly:
```bash
flutter run -d ios
```

**Using VS Code:**
- Press **F5**
- Select "Flutter: Run (iOS)"

---

## Quick Troubleshooting

**Simulator not showing in `flutter devices`:**
- Make sure Simulator app is open and showing a booted device
- Wait a few seconds and try `flutter devices` again

**CocoaPods not installed:**
```bash
brew install cocoapods
```

**Need more help?**
- Run diagnostics: `flutter doctor -v`
