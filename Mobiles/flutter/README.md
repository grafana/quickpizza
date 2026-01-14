# QuickPizza Flutter Mobile App

A Flutter mobile application that replicates the QuickPizza web application functionality. This app allows users to get pizza recommendations, rate pizzas, and manage their profile.

## Features

- 🍕 Get pizza recommendations with one click
- ⭐ Rate pizzas (Love it! or No thanks)
- 🔐 User login and profile management
- ⚙️ Advanced options for customizing pizza recommendations:
  - Max calories per slice
  - Min/Max number of toppings
  - Excluded tools
  - Vegetarian option
  - Custom pizza name
- 📊 View your pizza ratings history

## Setup

### Prerequisites

- Flutter SDK installed (3.10.1 or higher)
- QuickPizza backend running (default: `http://localhost:3333`)

### Platform-Specific Setup

**For Android development:**

- Follow the setup guide: [`../docs/ANDROID_SETUP.md`](../docs/ANDROID_SETUP.md)
- Quick check: Run `flutter doctor` - Android toolchain should show ✓
- **Quick start:** After setup, use `./scripts/run-android.sh` to automatically open emulator and run the app

**For iOS development (macOS only):**

- Follow the setup guide: [`../docs/XCODE_SETUP.md`](../docs/XCODE_SETUP.md)
- Quick check: Run `flutter doctor` - Xcode should show ✓
- **Quick start:** After setup, use `./scripts/run-ios.sh` to automatically open simulator and run the app

For detailed simulator/emulator setup and troubleshooting, see the documentation in [`../docs/`](../docs/).

### Installation

1. Install dependencies:

```bash
flutter pub get
```

2. Configure the app:

   a. Copy the example config file:

   ```bash
   cp config.json.example config.json
   ```

   b. Edit `config.json` with your values:

   ```json
   {
     "FARO_COLLECTOR_URL": "https://your-faro-collector.grafana.net/collect/xxx",
     "BASE_URL": "",
     "PORT": "3333"
   }
   ```

   **Configuration options:**

   - `FARO_COLLECTOR_URL`: Your Grafana Faro collector URL for observability
   - `BASE_URL`: Backend API URL (optional - see platform defaults below)
   - `PORT`: Backend port (optional, defaults to `3333`)

   **Platform defaults for BASE_URL:**

   - **Android emulator**: `http://10.0.2.2:3333` (automatically used if BASE_URL is empty)
   - **iOS simulator**: `http://localhost:3333` (automatically used if BASE_URL is empty)
   - **Physical devices**: You must set BASE_URL to your machine's IP (e.g., `http://192.168.1.100:3333`)

   > **💡 Tip:** To find your machine's IP address:
   >
   > - macOS: `ifconfig | grep "inet " | grep -v 127.0.0.1`
   > - Make sure your phone is on the same WiFi network as your development machine

3. Run the app:

```bash
# Using the helper scripts (recommended - includes config validation):
./scripts/run-android.sh
./scripts/run-ios.sh

# Or manually with flutter:
flutter run --dart-define-from-file=config.json
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── pizza.dart           # Pizza data models
│   ├── rating.dart          # Rating data model
│   └── restrictions.dart    # Pizza search restrictions model
├── screens/
│   ├── home_screen.dart     # Main pizza recommendation screen
│   └── login_screen.dart    # Login and profile screen
└── services/
    ├── api_service.dart     # API communication service
    └── config_service.dart  # Configuration service (handles env vars and platform detection)
```

## API Endpoints Used

- `GET /api/quotes` - Get random quote
- `GET /api/tools` - Get available pizza tools
- `POST /api/pizza` - Get pizza recommendation
- `POST /api/ratings` - Submit pizza rating
- `GET /api/ratings` - Get user's ratings
- `DELETE /api/ratings` - Clear all ratings
- `POST /api/users/token/login` - User login

## Default Login Credentials

- Username: `default`
- Password: `12345678`

## Running on Different Platforms

### Web

```bash
flutter run -d chrome
```

### Android

```bash
flutter run -d android
```

### iOS

```bash
flutter run -d ios
```

## Notes

- The app generates a random token for anonymous usage on first launch
- For authenticated features (ratings), users need to log in
- The app matches the web application's UI/UX as closely as possible
- All API calls follow the same structure as the web application
