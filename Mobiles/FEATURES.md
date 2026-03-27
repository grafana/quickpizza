# Android Native App — Required Screens & Workflows

This document lists the key screens and user workflows that the Android native app must support, based on the Flutter app and the Arbigent e2e test suite.

---

## Screens

### 1. Home Screen
The default screen shown on launch.

**Must display:**
- App bar with "QuickPizza" title and profile avatar button
- "Pizza, Please!" / "Get Pizza Recommendation" button
- Expandable "Customize Your Pizza" section
- Pizza recommendation card (after a successful request)
- Rating buttons on the pizza card ("Love it!" / "Pass")
- "Rated!" confirmation text after a rating is submitted

**Customize section must include:**
- Max calories per slice (slider or number input, min: 500)
- Min/max number of toppings
- Vegetarian only toggle
- Exclude tools (checkboxes or chips, loaded from API)
- Custom pizza name (optional text field)

**Pizza card must display:**
- Pizza name
- Dough type
- Tool used
- Calories per slice
- Ingredients list
- Vegetarian badge (if applicable)

---

### 2. Login Screen
Reached by tapping the profile avatar when unauthenticated.

**Must support:**
- Username and password fields
- Sign In button with loading state
- Error message on failed login
- Hint showing default credentials (`default` / `12345678`)
- Successful login redirects to Profile screen

---

### 3. Profile Screen
Reached by tapping the profile avatar when authenticated.

**Must display:**
- Username
- Number of pizzas rated
- List of rated pizzas with sentiment (loved / passed) and star count
- Empty state when no ratings exist

**Must support:**
- "Clear Ratings" button (visible only when ratings exist)
- "Sign Out" button — clears session and returns to Home

---

### 4. About Screen
Accessible from the bottom navigation bar.

**Must display:**
- App description and feature list
- Link to Faro / OTel SDK documentation or repo
- App version number

---

## Key Workflows

### W1: App Launch
1. App starts clean (no prior data).
2. Home screen is visible with the "Pizza, Please!" button.
3. Quote or tagline is displayed.

> Covered by Arbigent `start_app` scenario.

---

### W2: Get a Pizza Recommendation
1. User taps "Pizza, Please!" on the Home screen.
2. If not logged in, the login flow may be triggered (see W4).
3. A pizza recommendation card appears showing name, ingredients, and rating buttons.
4. Scrolling down reveals the full card including "Love it!" and "Pass" buttons.

> Covered by Arbigent `request_pizza` scenario.

---

### W3: Rate a Pizza
*Depends on W2.*

1. Pizza recommendation card is visible.
2. User taps "Love it!" or "Pass".
3. "Rated!" text appears below the rating buttons.

> Covered by Arbigent `rate_pizza` scenario.

---

### W4: Login
1. User taps profile avatar (unauthenticated).
2. Login screen appears.
3. User enters credentials (`default` / `12345678`).
4. On success, navigates to Profile screen.
5. Tools list on Home screen becomes available.

---

### W5: View and Manage Ratings
1. User taps profile avatar (authenticated).
2. Profile screen shows all previously rated pizzas.
3. User can tap "Clear Ratings" to delete all ratings (confirmed by empty state).
4. User can tap "Sign Out" to end session.

---

### W6: Background / Foreground
1. User presses the Home button — app goes to background.
2. User re-opens app from recents.
3. Home screen is restored correctly (no crash, state preserved).

> Covered by Arbigent `put_app_to_background` and `bring_app_to_foreground` scenarios.

---

## API Endpoints Required

| Endpoint | Method | Auth | Purpose |
|---|---|---|---|
| `/api/quotes` | GET | No | Home screen quote |
| `/api/tools` | GET | Yes | Populate exclude-tools list |
| `/api/pizza` | POST | Yes | Get recommendation |
| `/api/ratings` | POST | Yes | Submit rating |
| `/api/ratings` | GET | Yes | Load ratings on Profile |
| `/api/ratings` | DELETE | Yes | Clear all ratings |
| `/api/users/token/login` | POST | No | Authenticate |

---

## Observability Requirements

The app must instrument the following signals via OpenTelemetry (OTLP export):

| Signal | Examples |
|---|---|
| Traces | `pizza.get_recommendation`, `pizza.rate`, `auth.login`, auto-instrumented HTTP spans |
| Logs | Structured app logs, exception records with `exception.stacktrace` |
| Crashes | Unhandled exceptions captured and exported |
| Sessions | Session ID stamped on all telemetry, 15-min inactivity timeout |

Resource attributes on all telemetry:
- `service.name = quickpizza-android`
- `service.namespace = quickpizza`
- `service.version = <versionName>`
- `deployment.environment = production`
