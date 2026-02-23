# iOS App Architecture Guide

This document captures architectural decisions and best practices for building the QuickPizza iOS app. It serves as context for AI agents and developers working on the iOS codebase.

For telemetry-specific implementation details, see `IOS_OBSERVABILITY_OTEL_GUIDE.md`.

## Table of Contents

- [Project Setup](#project-setup)
- [Folder Structure](#folder-structure)
- [ViewModel Pattern](#viewmodel-pattern)
- [ViewModel Lifecycle & SwiftUI @State](#viewmodel-lifecycle--swiftui-state)
- [Dependency Injection with SwiftiePod](#dependency-injection-with-swiftiepod)
- [Clean Code: Protocol-Based Services](#clean-code-protocol-based-services)
- [Async Work & Subscriptions](#async-work--subscriptions)
- [Navigation](#navigation)
- [Reference: Flutter App Structure](#reference-flutter-app-structure)

---

## Project Setup 

- Use a **standard Xcode project** (`.xcodeproj`). This gives full IDE support for signing, capabilities, asset catalogs, and SwiftUI previews.
- **No storyboards** — SwiftUI apps are code-only. The entry point is an `@main` struct conforming to `App`.
- Use **Swift Package Manager** (integrated into Xcode) for dependencies — not CocoaPods.
- **Minimum deployment target: iOS 17+** — this enables the `@Observable` macro and modern SwiftUI APIs.
- The iOS app lives at `Mobiles/ios/` alongside the Flutter app at `Mobiles/flutter/`.
- **Build configuration** is managed via `Config.xcconfig` → `Scripts/generate-config.sh` → `BuildConfig.generated.swift`. This file is auto-generated and should not be edited manually.

---

## Folder Structure

Use feature-based organization. Each feature has `Domain/`, `Models/`, and `Presentation/` sub-folders. This mirrors the Flutter app's structure.

```
Mobiles/ios/QuickPizzaIos/
├── QuickPizzaIosApp.swift                # @main entry point
├── Bootstrap.swift                       # App setup, pod configuration, OTel init
├── Core/
│   ├── API/
│   │   ├── APIClientProtocol.swift       # Protocol
│   │   └── APIClient.swift               # URLSession-based implementation
│   ├── Config/
│   │   ├── ConfigService.swift           # Base URL, OTel endpoint, app version config
│   │   └── BuildConfig.generated.swift   # Auto-generated from Config.xcconfig (do not edit)
│   ├── Storage/
│   │   ├── TokenStoring.swift            # StoredSession model + TokenStoring protocol
│   │   └── UserDefaultsTokenStorage.swift
│   ├── O11y/
│   │   ├── Logger.swift                  # Logging protocol + CompositeLogger (OSLog + OTel)
│   │   ├── OTelConfig.swift              # OTel configuration values
│   │   └── OTelService.swift             # Traces, logs, URLSession instrumentation setup
│   ├── Theme/
│   │   └── AppTheme.swift                # AppColors, card styles, button styles
│   └── UI/
│       └── Components/                   # Shared reusable UI components
│           └── QuickPizzaAppBar.swift
├── Features/
│   ├── Auth/
│   │   ├── Domain/
│   │   │   ├── AuthServiceProtocol.swift
│   │   │   └── AuthRepository.swift
│   │   └── Presentation/
│   │       ├── LoginView.swift
│   │       └── LoginViewModel.swift
│   ├── Pizza/
│   │   ├── Domain/
│   │   │   ├── PizzaRepositoryProtocol.swift
│   │   │   └── PizzaRepository.swift
│   │   ├── Models/
│   │   │   ├── Pizza.swift
│   │   │   └── Restrictions.swift
│   │   └── Presentation/
│   │       ├── HomeView.swift
│   │       ├── HomeViewModel.swift
│   │       └── Components/
│   │           ├── PizzaCard.swift
│   │           ├── CustomizeSection.swift
│   │           └── RatingButtons.swift
│   ├── About/
│   │   ├── Models/
│   │   │   └── LinkItem.swift
│   │   └── Presentation/
│   │       └── AboutView.swift
│   └── Profile/
│       ├── Domain/
│       │   ├── RatingsRepositoryProtocol.swift
│       │   └── RatingsRepository.swift   # GET/DELETE /api/ratings
│       ├── Models/
│       │   └── Rating.swift              # Rating + RatingRequest models
│       └── Presentation/
│           ├── ProfileView.swift
│           └── ProfileViewModel.swift
├── Navigation/
│   └── MainShell.swift                   # TabView (Home, About) + sheet modals for Login/Profile
└── Resources/
    └── Assets.xcassets
```

### Conventions

- **Everything is a `View`** in SwiftUI. Both full-screen pages and small sub-components end in `*View.swift`. The folder structure distinguishes them:
  - **Screen-level views** (full pages like `HomeView.swift`, `LoginView.swift`) live directly in `Presentation/`.
  - **Extracted sub-components** (e.g., `PizzaCard.swift`, `AnimatedPizzaHeaderView.swift`) live in `Presentation/Components/`.
- **ViewModels** are named `*ViewModel.swift` and placed next to their screen-level View in `Presentation/`.
- **Protocols** (interfaces) are defined in separate files or at the top of the file alongside the implementation.
- **Domain** folder holds service protocols and repository implementations.
- **Models** folder holds plain data types (structs with `Codable`).
- **Presentation** folder holds Views, ViewModels, and feature-specific components.
- **Components** folder holds extracted sub-views. Only move UI into `Components/` when it's substantial enough to warrant its own file — because it has meaningful logic, its own ViewModel, or is reused. Small extractions can stay as private computed properties or `@ViewBuilder` methods within the parent View file.
- **Core/UI/Components** holds shared components used across multiple features (e.g., `QuickPizzaAppBar.swift`).
- **Core** holds shared infrastructure used across all features.
- Do NOT use the name "Widgets" — in iOS, "Widget" refers to WidgetKit (home screen widgets) and would be confusing.

---

## ViewModel Pattern

Use the **`@Observable` macro** (iOS 17+). This replaces the older `ObservableObject` + `@Published` pattern.

### Basic ViewModel structure

```swift
import SwiftUI
import SwiftiePod

// Provider — co-located at the top of the file, creates a fresh instance per view
let homeViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    HomeViewModel(
        pizzaRepository: pod.resolve(pizzaRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}

@Observable
class HomeViewModel {
    // Dependencies — injected via constructor
    private let pizzaRepository: PizzaRepositoryProtocol
    private let logger: Logging

    // View state — @Observable tracks these automatically
    var pizza: Pizza?
    var isLoading = false
    var errorMessage: String?

    init(pizzaRepository: PizzaRepositoryProtocol, logger: Logging) {
        self.pizzaRepository = pizzaRepository
        self.logger = logger
    }

    func fetchRecommendation(restrictions: Restrictions) async {
        isLoading = true
        defer { isLoading = false }
        do {
            pizza = try await pizzaRepository.getRecommendation(restrictions)
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to fetch pizza", error: error)
        }
    }
}
```

### Using the ViewModel in a View

```swift
struct HomeView: View {
    @State private var viewModel = pod.resolve(homeViewModelProvider)

    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView()
            } else if let pizza = viewModel.pizza {
                PizzaCard(pizza: pizza)
            }
        }
        .task {
            await viewModel.fetchRecommendation(restrictions: .default)
        }
    }
}
```

### Key rules

- `@Observable` auto-tracks all stored properties. No `@Published` needed.
- SwiftUI only redraws when the specific properties accessed in `body` change (fine-grained).
- Use `@Bindable` for two-way bindings (e.g., `TextField($viewModel.name)`).
- Dependencies are injected via **constructor** — never via method calls after init.

---

## ViewModel Lifecycle & SwiftUI @State

This section is critical. Getting this wrong causes subtle state bugs.

### Core mental model

SwiftUI views are **structs** (value types). They are **ephemeral** — SwiftUI creates and discards them freely. The `body` property is evaluated to build an internal render tree. **The lifetime of a view struct is NOT the same as the lifetime of the on-screen view.**

`@State` bridges this gap. It tells SwiftUI: "manage the storage of this property — keep it alive as long as this view exists in the hierarchy."

### What happens with `@State private var viewModel = SomeViewModel()`

1. **First time** the view appears: SwiftUI calls the View's init, evaluates `SomeViewModel()`, and stores the instance in internal state storage.
2. **On every subsequent parent redraw**: SwiftUI calls the View's init again. `SomeViewModel()` is evaluated again — a new instance is allocated. But SwiftUI **discards** this new instance and continues using the original one.
3. **View removed from hierarchy** (popped, `if` condition changes): @State storage is destroyed, the ViewModel is deallocated (`deinit` runs).

**Consequence**: The ViewModel's `init()` may be called multiple times, but extra instances are discarded. Keep `init()` lightweight — just store dependencies, set defaults. No network calls, no subscriptions in `init()`.

### @State ignores new initial values

If a parent passes a changing parameter:

```swift
// Parent rebuilds with different value
HomeView(count: 4)  // was 3 before
```

The `@State` property **ignores** the new initial value. It only uses the first value. To react to parameter changes:

- **`.onChange(of:)`** — to update the existing ViewModel:
  ```swift
  .onChange(of: count) { _, newValue in
      viewModel.updateCount(newValue)
  }
  ```
- **`.task(id:)`** — to re-run async work when a parameter changes:
  ```swift
  .task(id: userId) {
      await viewModel.loadUser(userId)
  }
  ```
- **`.id(value)`** on the parent — to force complete view destruction and recreation.
- **Plain `let` properties** — if it's just display data, don't put it in the ViewModel at all. Pass it as a regular property on the View.

### Navigation lifecycle

- **Push** a view onto `NavigationStack`: new @State created, new ViewModel.
- **Pop** a view: @State destroyed, ViewModel deallocated (if no retain cycles).
- **Re-push** the same screen: brand new @State, brand new ViewModel, fresh state.

---

## Dependency Injection with SwiftiePod

Use **SwiftiePod** (v1.0.8) as the service locator / DI container. Add it via Swift Package Manager:

```
.package(url: "https://github.com/robert-northmind/SwiftiePod.git", from: "1.0.8")
```

### Pod setup

Create a single global pod instance at app startup:

```swift
import SwiftiePod

let pod = SwiftiePod()
```

### Provider definitions

Providers are defined **co-located** with the types they serve — at the top of the same file. This keeps the provider close to its implementation and avoids a single large file.

```swift
// In Logger.swift — co-located with the Logging protocol and implementations
import SwiftiePod

let loggerProvider = Provider<Logging> { pod in
    let subsystem = Bundle.main.bundleIdentifier ?? "com.grafana.QuickPizzaIos"
    return CompositeLogger(loggers: [
        ConsoleLogger(subsystem: subsystem),
        OtelLogger(otelLogger: pod.resolve(otelServiceProvider).getLogger()),
    ])
}
```

```swift
// In HomeViewModel.swift — co-located with the ViewModel
let homeViewModelProvider = Provider(scope: AlwaysCreateNewScope()) { pod in
    HomeViewModel(
        pizzaRepository: pod.resolve(pizzaRepositoryProvider),
        authService: pod.resolve(authRepositoryProvider),
        logger: pod.resolve(loggerProvider)
    )
}
```

```swift
// In ConfigService.swift — co-located with ConfigService
let configServiceProvider = Provider { _ in
    ConfigService()
}
```

### Scoping rules

| What | Scope | Why |
|------|-------|-----|
| Services (APIClient, Logger, TokenStorage) | `SingletonScope` (default) | Shared, app-lifetime, stateless or app-scoped state |
| Repositories | `SingletonScope` (default) | Shared, stateless data access layer |
| ViewModels | `AlwaysCreateNewScope()` | Each view needs its own fresh instance; `@State` manages its lifetime |

### Usage in Views

```swift
struct HomeView: View {
    @State private var viewModel = pod.resolve(homeViewModelProvider)

    var body: some View {
        // ...
    }
}
```

`@State` keeps the resolved ViewModel alive. SwiftiePod's `AlwaysCreateNewScope` ensures a fresh instance each time `resolve()` is called, but `@State` prevents re-resolution on parent redraws (it discards the extra instances).

### Testing with overrides

```swift
// In tests or SwiftUI previews
pod.overrideProvider(pizzaRepositoryProvider) { _ in
    MockPizzaRepository()
}
```

---

## Clean Code: Protocol-Based Services

Define protocols (interfaces) for all services. Never call frameworks like `UserDefaults`, `URLSession`, or third-party SDKs directly inside business logic. Inject abstractions instead.

### Pattern

```swift
// Protocol (interface) — in TokenStoring.swift
protocol TokenStoring {
    func saveSession(token: String, username: String)
    func loadSession() -> StoredSession
    func clearSession()
}

struct StoredSession: Equatable {
    let token: String?
    let username: String?
    static let empty = StoredSession(token: nil, username: nil)
    var isAuthenticated: Bool { token != nil && !(token?.isEmpty ?? true) }
}

// Real implementation — in UserDefaultsTokenStorage.swift
class UserDefaultsTokenStorage: TokenStoring {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func saveSession(token: String, username: String) { /* ... */ }
    func loadSession() -> StoredSession { /* ... */ }
    func clearSession() { /* ... */ }
}

// Mock for testing
class MockTokenStorage: TokenStoring {
    var session: StoredSession = .empty
    func saveSession(token: String, username: String) {
        session = StoredSession(token: token, username: username)
    }
    func loadSession() -> StoredSession { session }
    func clearSession() { session = .empty }
}
```

### When to be pragmatic

Do NOT force this pattern everywhere. Skip the protocol when:
- The type is trivial and will never be mocked (e.g., `Date()`, `UUID()`).
- It adds complexity without testability benefit.
- It's a pure data model or value type.

DO use protocols when:
- The implementation wraps an external framework (UserDefaults, URLSession, Keychain, OTel SDK).
- You need to swap implementations for testing.
- Multiple implementations exist (e.g., real vs. mock API client).

---

## Async Work & Subscriptions

### The recommended pattern: cheap init + `.task { await start() }`

Do NOT set up subscriptions or async work in the ViewModel's `init()`. The `init()` may be called multiple times due to SwiftUI's view struct re-initialization behavior.

Instead, use a `start()` method called from `.task { }`:

```swift
@Observable
class HomeViewModel {
    private let authService: AuthServiceProtocol
    var isLoggedIn = false

    // Init is cheap — just stores dependencies
    init(authService: AuthServiceProtocol) {
        self.authService = authService
    }

    // Subscriptions happen here. Called from .task { }
    func start() async {
        for await status in authService.authStatusStream {
            isLoggedIn = (status == .authenticated)
        }
    }
}
```

```swift
struct HomeView: View {
    @State private var viewModel = pod.resolve(homeViewModelProvider)

    var body: some View {
        // ...
        .task {
            await viewModel.start()
        }
    }
}
```

### Why `.task { }` is ideal

- Runs when the view **appears** in the hierarchy.
- **Auto-cancels** the `Task` when the view **disappears** (popped, removed).
- Only runs **once** per view appearance (not on every parent redraw).
- Uses Swift structured concurrency — cleanup is automatic.

### Multiple concurrent subscriptions

Use `withTaskGroup` inside `start()`:

```swift
func start() async {
    await withTaskGroup(of: Void.self) { group in
        group.addTask { @MainActor in
            for await status in self.authService.authStatusStream {
                self.isLoggedIn = (status == .authenticated)
            }
        }
        group.addTask { @MainActor in
            for await event in self.pizzaService.pizzaUpdates {
                self.latestPizza = event
            }
        }
    }
}
```

When `.task` cancels, the entire task group is cancelled — all subscriptions stop.

### Reacting to parameter changes

Use `.task(id:)`:

```swift
.task(id: userId) {
    await viewModel.loadData(for: userId)
}
```

This cancels the previous task and re-runs with the new value.

---

## Navigation

Use `NavigationStack` with a `TabView` for bottom navigation (matching the Flutter app's shell route with bottom nav).

```swift
struct MainShell: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                AboutView()
            }
            .tabItem { Label("About", systemImage: "info.circle") }
        }
    }
}
```

---

## Reference: Flutter App Structure

The iOS app mirrors the Flutter app's architecture. Here's the mapping:

| Flutter | iOS |
|---------|-----|
| `main.dart` | `QuickPizzaIosApp.swift` |
| `bootstrap.dart` | `Bootstrap.swift` |
| Riverpod `Provider` | SwiftiePod `Provider` (co-located in each file) |
| Riverpod `Notifier` | `@Observable` ViewModel class |
| `ConsumerWidget` | SwiftUI `View` with `@State` ViewModel |
| `ref.watch(provider)` | `pod.resolve(provider)` |
| `core/api/api_client.dart` | `Core/API/APIClient.swift` |
| `features/pizza/domain/` | `Features/Pizza/Domain/` |
| `features/pizza/models/` | `Features/Pizza/Models/` |
| `features/pizza/presentation/` | `Features/Pizza/Presentation/` |
| GoRouter | `NavigationStack` + `TabView` |
| `.task { }` in Riverpod `build()` | `.task { await viewModel.start() }` |

### Flutter features to replicate

- **Auth**: Login screen, token-based auth, session persistence
- **Pizza**: Pizza recommendation with customization, quote display
- **Ratings**: Rate pizzas, view/delete ratings
- **About**: App info, links
- **Profile**: User profile, ratings history, sign out
- **Observability**: OpenTelemetry Swift for traces and logs (OSLog + OTel dual logging)

---

## Quick Reference: SwiftUI State Property Wrappers

| Wrapper | Use for |
|---------|---------|
| `@State` | View-owned state: primitives, structs, `@Observable` class instances |
| `@Binding` | Two-way connection to a parent's `@State` |
| `@Bindable` | Two-way binding to `@Observable` class properties |
| `@Environment(\.key)` | Reading SwiftUI environment values (theme, locale, custom keys) |
| `@Environment(Type.self)` | Reading `@Observable` objects from the environment |

Do NOT use the older `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, or `@Published` — these are the pre-iOS 17 pattern.
