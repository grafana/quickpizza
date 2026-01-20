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
├── core/                     # Shared infrastructure & cross-cutting concerns
│   ├── config/              # App configuration & environment
│   ├── localization/        # i18n/l10n support
│   ├── o11y/                # Observability (logging, errors, events, metrics)
│   ├── router/              # Navigation/routing setup
│   └── theme/               # Theming & colors
└── features/                 # Feature modules (see Architecture below)
```

## Architecture

This app follows an **MVVM (Model-View-ViewModel)** architecture pattern with clear separation of concerns. Each feature is organized into three layers:

### Feature Folder Structure

```
features/
└── pizza/                    # Example feature
    ├── domain/              # Business logic layer
    │   ├── pizza_provider.dart      # Domain providers & notifiers
    │   └── pizza_repository.dart    # Data access & API calls
    ├── presentation/        # Presentation layer
    │   ├── home_screen.dart         # UI (widgets)
    │   ├── home_screen_view_model.dart  # ViewModel (UI state + actions)
    │   └── widgets/                 # Reusable UI components
    └── models/              # Data models
        ├── pizza.dart
        └── restrictions.dart
```

### Layer Responsibilities

| Layer             | Purpose                      | Contains                                       |
| ----------------- | ---------------------------- | ---------------------------------------------- |
| **domain/**       | Business logic & data access | Repositories, domain providers, business rules |
| **presentation/** | UI & presentation logic      | Screens, ViewModels, widgets                   |
| **models/**       | Data structures              | Pure data classes, no behavior                 |

### ViewModel Pattern

ViewModels follow a hybrid Riverpod pattern that provides clean separation:

```dart
// UI State - pure data class
class RatingButtonsUiState {
  const RatingButtonsUiState({this.rateResult, this.isLoading = false});

  final String? rateResult;
  final bool isLoading;
}

// Actions interface - defines what the ViewModel can do
abstract interface class RatingButtonsActions {
  Future<void> ratePizza({required int stars});
}

class RatingButtonsViewModel extends Notifier<RatingButtonsUiState>
    implements RatingButtonsActions {
  RatingButtonsViewModel(this.pizzaId);
  final int pizzaId;

  @override
  RatingButtonsUiState build() => const RatingButtonsUiState();

  @override
  Future<void> ratePizza({required int stars}) async { /* ... */ }
}

// UI State provider with family parameter
final ratingButtonsUiStateProvider = NotifierProvider.family<
    RatingButtonsViewModel, RatingButtonsUiState, int>(
  RatingButtonsViewModel.new,
);

// Actions provider - exposes the interface, hides Riverpod details
final ratingButtonsActionsProvider = Provider.family<RatingButtonsActions, int>(
  (ref, pizzaId) => ref.watch(ratingButtonsUiStateProvider(pizzaId).notifier),
);

// Usage in widgets
final uiState = ref.watch(ratingButtonsUiStateProvider(pizzaId));
final actions = ref.watch(ratingButtonsActionsProvider(pizzaId));
onPressed: () => actions.ratePizza(stars: 5);
```

**Benefits:**

- **Testability**: Easy to mock `RatingButtonsActions` interface in tests
- **Readability**: No Riverpod-specific syntax (`.notifier`) in widget code
- **Separation**: UI state is a pure data class, actions are interface methods
- **Discoverability**: New developers see plain Dart interfaces

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

## AI-Assisted Testing with MCP

This app supports AI-assisted testing via the Dart MCP server. An AI assistant (like Cursor) can navigate, interact with, and test the running app.

### Setup

1. **Launch with Flutter Driver enabled:**

   - In VS Code/Cursor, select **"Flutter (debug with driver)"** from the Run and Debug panel
   - Or run: `flutter run --dart-define-from-file=config.json lib/driver_main.dart`

2. **Get the DTD (Dart Tooling Daemon) URI:**

   - After the app launches, look in the Debug Console for the DTD URI
   - Or use the **"Copy DTD URI to clipboard"** action in VS Code/Cursor
   - The URI looks like: `ws://127.0.0.1:61788/Jc_1sL6labM=`

3. **Provide the DTD URI to your AI assistant:**
   - Tell the AI: "Here is the DTD: `ws://...`"
   - The AI can then connect and interact with your app (tap buttons, enter text, scroll, inspect widgets)

### What the AI can do

- Navigate between screens
- Tap buttons and interact with UI elements
- Enter text in form fields
- Scroll views
- Inspect the widget tree
- Verify UI state and content

> **Note:** The `driver_main.dart` entry point enables Flutter Driver extension which is required for programmatic interaction.

## Versioning

When adding new features or making significant changes, bump the version in `pubspec.yaml`:

```yaml
version: 1.2.0
```

This ensures the Faro SDK tracks different versions in telemetry, which is useful for:
- Demonstrating version-based filtering in Grafana dashboards
- Showing how metrics differ between app versions
- Creating realistic observability demo scenarios

## Notes

- The app generates a random token for anonymous usage on first launch
- For authenticated features (ratings), users need to log in
- The app matches the web application's UI/UX as closely as possible
- All API calls follow the same structure as the web application
