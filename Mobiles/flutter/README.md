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

2. Configure the backend endpoint:
   
   The app automatically detects the platform and uses appropriate URLs:
   - **Android emulator**: `http://10.0.2.2:3333` (automatically used)
   - **iOS simulator**: `http://localhost:3333` (automatically used)
   - **Physical devices**: Requires manual configuration via `.env` file
   
   To customize the backend URL:
   
   a. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   
   b. Edit `.env` and set `BASE_URL`:
   ```bash
   # For physical devices, use your machine's IP address
   BASE_URL=http://192.168.1.100:3333
   
   # Or use a remote server
   BASE_URL=https://api.example.com
   ```
   
   If `BASE_URL` is not set in `.env`, the app will use platform-specific defaults.

3. Run the app:
```bash
flutter run
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
