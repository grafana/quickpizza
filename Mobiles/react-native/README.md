# QuickPizza React Native Demo App

A React Native mobile application that replicates the QuickPizza web and Flutter app functionality. This app demonstrates Grafana Faro SDK integration for mobile observability.

## Features

- Get pizza recommendations with one click
- Rate pizzas (Love it! or No thanks)
- User login and profile management
- Advanced options for customizing pizza recommendations
- View your pizza ratings history

## Prerequisites

- Node.js >= 22
- Yarn
- React Native development environment ([setup guide](https://reactnative.dev/docs/environment-setup))
- QuickPizza backend running (default: `http://localhost:3333`)

## Setup

### 1. Install dependencies

```bash
yarn install
```

### 2. Configure the app

Copy the example config and add your values (same approach as the Flutter app):

```bash
cp config.json.example config.json
```

Edit `config.json`:

- **FARO_COLLECTOR_URL** (required): Your Grafana Faro collector URL for observability
- **BASE_URL** (optional): Backend API URL. Leave empty for emulators (uses 10.0.2.2 for Android, localhost for iOS)
- **PORT** (optional): Backend port, defaults to 3333

For physical devices, set `BASE_URL` to your machine's IP (e.g. `http://192.168.1.100:3333`).

### 3. iOS: Install CocoaPods

```bash
cd ios && pod install && cd ..
```

## Running the app

### Start the QuickPizza backend

**Option A – Monolithic (simple):**

```bash
docker run --rm -it -p 3333:3333 ghcr.io/grafana/quickpizza-local:latest
```

**Option B – Microservices with Grafana Cloud observability** (from the `mobile-o11y-demo` root):

Create a `.env` file with `GRAFANA_CLOUD_STACK` and `GRAFANA_CLOUD_TOKEN`, then:

```bash
docker compose -f compose.grafana-cloud.microservices.yaml up -d
```

### Run the app

```bash
# Start Metro bundler (in one terminal)
yarn start

# Run on iOS (in another terminal)
yarn ios
# or
./scripts/run-ios.sh

# Run on Android
yarn android
# or
./scripts/run-android.sh
```

## Default login credentials

- Username: `default`
- Password: `12345678`

## Faro SDK

This app uses `@grafana/faro-react-native` and `@grafana/faro-react-native-tracing` from the sibling `faro-react-native-sdk` repository (via `file:` dependency). When the SDK is published, update `package.json` to use the npm version.

## Project structure

```
src/
├── core/           # Config, API client, o11y layer, theme
├── features/       # Auth, pizza, profile, about
├── navigation/     # React Navigation setup
└── bootstrap.ts    # Faro initialization
```

## API endpoints

- `GET /api/quotes` - Random quote
- `GET /api/tools` - Pizza tools
- `POST /api/pizza` - Pizza recommendation
- `POST /api/ratings` - Submit rating
- `GET /api/ratings` - User ratings
- `DELETE /api/ratings` - Clear ratings
- `POST /api/users/token/login` - Login
