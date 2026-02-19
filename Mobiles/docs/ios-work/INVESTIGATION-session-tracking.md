# Session Tracking Investigation

> Investigation into adding session tracking to the iOS demo app using the OpenTelemetry Swift SDK's built-in Sessions module.

## Current State

### iOS Demo App (OTelService.swift)

The app uses `opentelemetry-swift` v2.3.0 with:

- **Traces**: `OtlpHttpTraceExporter` → `{endpoint}/v1/traces` via `BatchSpanProcessor`
- **Logs**: `OtlpHttpLogExporter` → `{endpoint}/v1/logs` via `BatchLogRecordProcessor`
- **Auto-instrumentation**: `URLSessionInstrumentation` for HTTP requests
- **Resources**: `service.name`, `service.namespace`, `service.version`, `service.build`, `deployment.environment`
- **No session tracking** is currently in place

The `Sessions` library product from `opentelemetry-swift` is **not yet added** to the Xcode project, but the package itself is already a dependency at v2.3.0 which includes it.

---

## OTel Swift SDK Sessions Module

**Location**: `opentelemetry-swift/Sources/Instrumentation/Sessions/`  
**Package product**: `Sessions`  
**Available since**: v2.3.0 (the version the demo app already uses)

### Architecture Overview

```
SessionConfig          -- Configuration (timeout duration)
    │
    ▼
SessionManager         -- Core lifecycle management (concrete class, not protocol)
    │
    ├─── Session       -- Value type (id, expireTime, previousId, startTime)
    │
    ├─── SessionStore  -- Persistence to UserDefaults
    │
    ▼
SessionManagerProvider -- Thread-safe singleton access
    │
    ├─── SessionSpanProcessor           -- Adds session.id to all spans
    ├─── SessionLogRecordProcessor      -- Adds session.id to all log records
    └─── SessionEventInstrumentation    -- Emits session.start / session.end log events
```

### Session Lifecycle

1. **Creation**: First call to `getSession()` creates a new session with `UUID().uuidString`
2. **Extension**: Every subsequent `getSession()` call extends `expireTime` by `sessionTimeout`
3. **Expiry**: When `expireTime <= Date()`, session is considered expired
4. **Rotation**: Next `getSession()` after expiry creates a new session with `previousId` linking to the old one
5. **Events**: Expired sessions emit `session.end`; new sessions emit `session.start`
6. **Persistence**: Sessions are persisted to UserDefaults every 30 seconds and restored on app restart

### Configuration

```swift
let config = SessionConfig(sessionTimeout: 15 * 60) // 15 minutes
let manager = SessionManager(configuration: config)
SessionManagerProvider.register(sessionManager: manager)
```

Only one configuration knob: `sessionTimeout` (default: 30 minutes).

### How It Integrates

The module provides **processors** that plug into the standard OTel pipeline:

```swift
// 1. Register session manager
SessionManagerProvider.register(sessionManager: sessionManager)

// 2. Add session span processor
let tracerProvider = TracerProviderBuilder()
    .add(spanProcessor: SessionSpanProcessor())
    .add(spanProcessor: BatchSpanProcessor(spanExporter: otlpExporter))
    .with(resource: resource)
    .build()

// 3. Wrap log processors
let sessionLogProcessor = SessionLogRecordProcessor(
    nextProcessor: BatchLogRecordProcessor(logRecordExporter: otlpLogExporter)
)
let loggerProvider = LoggerProviderBuilder()
    .with(processors: [sessionLogProcessor])
    .with(resource: resource)
    .build()

// 4. Install event instrumentation (session.start / session.end logs)
SessionEventInstrumentation.install()
```

### Telemetry Output

**On every span**:

- `session.id` = current session UUID
- `session.previous_id` = previous session UUID (if any)

**On every log record**:

- `session.id` = current session UUID
- `session.previous_id` = previous session UUID (if any)

**Session lifecycle events** (as log records):

- `session.start` with `session.id`, `session.previous_id`
- `session.end` with `session.id`, `session.previous_id`

---

## Gap Analysis: OTel Sessions vs. Faro Session Rules

### Faro Session Rules

| Rule                             | Description                                                         |
| -------------------------------- | ------------------------------------------------------------------- |
| **New session on app start**     | A fresh session is always created when the app launches             |
| **Inactivity timeout**           | 15 minutes of inactivity → session expires                          |
| **Max session duration**         | 4 hours total → session expires regardless of activity              |
| **New session on next activity** | After either timeout, the next user activity triggers a new session |

### OTel SDK Session Behavior

| Capability                    | Status            | Notes                                                                                                                            |
| ----------------------------- | ----------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| New session on app start      | **Partial**       | Restores from UserDefaults. If the persisted session hasn't expired, it continues. A fresh app install will start a new session. |
| Inactivity timeout            | **Supported**     | Configurable via `SessionConfig.sessionTimeout` (default 30min, can set to 15min)                                                |
| Max session duration          | **NOT supported** | The SDK only tracks inactivity timeout. There is no `maxSessionDuration` concept.                                                |
| Session rotation with linking | **Supported**     | New sessions carry `previousId` pointing to the expired session                                                                  |
| Persistence across restarts   | **Supported**     | UserDefaults-based, restored on init                                                                                             |

### Key Gap: No Max Session Duration

The OTel SDK's `SessionManager` uses a **sliding window** timeout only. Every `getSession()` call resets the expiry clock. There is no concept of "this session has been alive for 4 hours, force-expire it."

The `SessionConfig` struct only has one field: `sessionTimeout` (the inactivity timeout). There is no `maxSessionDuration` field.

### Key Gap: Session Continuation on App Start

The OTel SDK restores the previous session from UserDefaults on init. If the previous session hasn't expired (within the inactivity timeout window), it continues that session. Faro always starts a new session on a fresh app launch.

### Key Gap: No Manual Session Control

`SessionManager` only exposes two public methods: `getSession()` and `peekSession()`. There is no `startNewSession()`, `endSession()`, or `invalidate()` method.

`previous_id` chaining is fully automatic — when a session expires and a new one is created, the new session's `previousId` is set to the old session's `id`. No manual management needed for that.

**Can you force a new session by re-registering?** No. Calling `SessionManagerProvider.register(sessionManager: SessionManager())` creates a fresh manager, but its `init` calls `restoreSessionFromDisk()` which loads the old (unexpired) session from UserDefaults. You'd get the same session back.

You _could_ manually clear the UserDefaults keys (`"otel-session-id"`, `"otel-session-expire-time"`, etc.) before creating a new manager, but those keys are implementation details of `SessionStore` (which is `internal`). This approach is fragile and could break silently on SDK upgrades.

### Key Gap: Minimal Metadata

The SDK only sends two attributes on telemetry: `session.id` and `session.previous_id`. No session duration, start time, device info, or reason-for-end metadata is included as attributes. Timing info is only carried via the log record's timestamp field on `session.start`/`session.end` events.

---

## Options for Bridging the Gaps

### Option 1: Use OTel Sessions As-Is (Minimal Gap)

**What**: Add the `Sessions` library, configure with 15min timeout, accept the missing max-duration rule.

**Pros**:

- Zero custom code — just wire up existing components
- Get session tracking working immediately
- Follows OTel semantic conventions (`session.id`, `session.previous_id`)
- Persistence and thread safety built-in

**Cons**:

- No 4-hour max session duration enforcement
- Sessions may survive app restarts (not a fresh session every launch)

**Effort**: Very low (~20 lines of changes in `OTelService.swift`)

### Option 2: Custom SessionManager Subclass

**What**: Subclass `SessionManager` to add max-duration logic and fresh-start-on-launch behavior.

**Challenge**: `SessionManager` is a **concrete class** (not a protocol). The `getSession()` method is not virtual/overridable by default in Swift (it's not marked `open`, just `public`). However, `SessionSpanProcessor` and `SessionLogRecordProcessor` both accept a `SessionManager` parameter directly.

**Approach**:

- Since `SessionManager` is `public class` (not `final`), subclassing _may_ work depending on whether Swift allows overriding `public` methods from a different module (it does if they're `open`). Need to verify if `getSession()` is `open` or just `public`.

**Verdict**: Looking at the source — `SessionManager` is declared as `public class` and `getSession()` as `public func`. In Swift, **`public` methods cannot be overridden from outside the module** — only `open` methods can be. So **subclassing won't work** for overriding behavior.

### Option 3: Fork/Wrap — Custom Session Manager with Same Interface

**What**: Write our own `FaroSessionManager` that wraps or replaces `SessionManager`, implementing the Faro rules. Pass it to the SDK's processors.

**Approach**:

- `SessionSpanProcessor` and `SessionLogRecordProcessor` accept `SessionManager` in their constructors
- BUT they expect the concrete `SessionManager` type, not a protocol
- So we can't substitute a custom implementation without also modifying those processors

**Challenge**: No protocol abstraction. The processors are tightly coupled to `SessionManager`.

### Option 4: Write Custom Span/Log Processors (Recommended for Full Control)

**What**: Instead of using `SessionSpanProcessor` and `SessionLogRecordProcessor`, write our own processors that manage sessions with Faro-compatible rules.

**Approach**:

1. Create a `FaroSessionManager` (standalone, doesn't need to extend OTel's `SessionManager`)
2. Implement Faro rules: 15min inactivity, 4hr max duration, new session on app start
3. Create `FaroSessionSpanProcessor: SpanProcessor` that adds `session.id` from our manager
4. Create `FaroSessionLogRecordProcessor: LogRecordProcessor` that adds `session.id` from our manager
5. Use the same `session.id` / `session.previous_id` attribute keys for compatibility

**Pros**:

- Full control over session lifecycle rules
- Uses the clean `SpanProcessor` and `LogRecordProcessor` protocols (well-defined extension points)
- Can implement exact Faro semantics
- No dependency on OTel's Sessions module (fewer things to break on upgrades)

**Cons**:

- More code to write and maintain
- Need to handle persistence ourselves (can still use UserDefaults)
- Need to handle thread safety ourselves

**Effort**: Medium (~150-250 lines of custom code)

### Option 5: Hybrid — Use OTel SessionManager + Custom Wrapper Logic

**What**: Use the OTel `SessionManager` for the inactivity timeout (set to 15min), but wrap it with additional logic for max-duration and fresh-start.

**Approach**:

1. Use `SessionManager(configuration: SessionConfig(sessionTimeout: 15 * 60))`
2. Create a thin wrapper that:
   - On app start: clears UserDefaults session keys, then lets SessionManager create fresh
   - Tracks `sessionStartTime` separately
   - On each `getSession()` call, checks if `Date() - sessionStartTime > 4 hours` → if so, clear and recreate
3. Pass the underlying `SessionManager` to the SDK's processors

**Pros**:

- Reuses most of the OTel infrastructure
- Less custom code than Option 4
- Still uses SDK processors

**Cons**:

- Somewhat hacky (clearing UserDefaults keys to force new sessions)
- The max-duration check would need to be done _before_ the processors call `getSession()`
- Fragile coupling to implementation details (`SessionStore` keys are `internal`)

**Effort**: Low-medium

---

## Recommendation

I'd suggest we discuss two viable paths:

**Path A — Start simple (Option 1), iterate later**:
Use the built-in Sessions module as-is with a 15-minute timeout. Accept the missing max-duration rule for now. This gets session tracking working immediately with ~20 lines of code. We can add max-duration later if needed.

**Path B — Full control from the start (Option 4)**:
Write custom processors with a `FaroSessionManager`. More work upfront but gives us exact Faro semantics. The `SpanProcessor` and `LogRecordProcessor` protocols are clean, well-defined extension points — this is the intended way to customize behavior.

> **Open question**: How strict does Grafana Cloud / the Faro backend need the session rules to be? If the 4-hour max duration and fresh-on-launch rules are critical for proper dashboard/query behavior, we need Option 4. If they're "nice to have" and the Faro backend can handle slightly different session semantics, Option 1 is the pragmatic choice.

---

## Integration Points in Current Codebase

The changes would go in `OTelService.swift`. Here's where things plug in:

```swift
// In setupTraces():
// Add SessionSpanProcessor (or custom) BEFORE the BatchSpanProcessor
spanProcessors.insert(SessionSpanProcessor(), at: 0)  // or custom

// In setupLogs():
// Wrap the BatchLogRecordProcessor with SessionLogRecordProcessor (or custom)
let sessionLogProcessor = SessionLogRecordProcessor(
    nextProcessor: BatchLogRecordProcessor(logRecordExporter: otlpLogExporter)
)

// In initialize():
// Install session event instrumentation
SessionEventInstrumentation.install()
```

The `import Sessions` would need to be added, and the `Sessions` product added to the Xcode project's target dependencies (from the already-existing `opentelemetry-swift` package).

---

---

## How Session Data Looks on the Wire (OTLP)

### Where session.id lives in the data model

Session attributes are added as **span-level attributes** and **log record-level attributes** — NOT as resource attributes. This is an important distinction.

```
OTLP Export Structure:
┌─────────────────────────────────────────────────┐
│ Resource                                        │
│   service.name = "quickpizza-ios"               │
│   service.version = "1.0.0"                     │
│   deployment.environment = "production"          │
│   (NO session.id here)                          │
│                                                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ Span: "pizza.get_recommendation"            │ │
│ │   Attributes:                               │ │
│ │     session.id = "A1B2C3D4-..."             │ │  ← added by SessionSpanProcessor
│ │     session.previous_id = "X9Y8Z7-..."      │ │  ← added by SessionSpanProcessor
│ │     pizza.vegetarian = true                  │ │  ← app's own attribute
│ │     http.status_code = 200                   │ │
│ └─────────────────────────────────────────────┘ │
│                                                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ LogRecord: "Login successful"               │ │
│ │   Attributes:                               │ │
│ │     session.id = "A1B2C3D4-..."             │ │  ← added by SessionLogRecordProcessor
│ │     session.previous_id = "X9Y8Z7-..."      │ │  ← added by SessionLogRecordProcessor
│ │     username = "chef42"                     │ │  ← app's own attribute
│ └─────────────────────────────────────────────┘ │
│                                                  │
│ ┌─────────────────────────────────────────────┐ │
│ │ LogRecord (Event): "session.start"          │ │  ← emitted by SessionEventInstrumentation
│ │   event.name = "session.start"              │ │
│ │   Attributes:                               │ │
│ │     session.id = "A1B2C3D4-..."             │ │
│ │     session.previous_id = "X9Y8Z7-..."      │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

### Concrete OTLP JSON example

Every span exported via OTLP would include the session attributes in its `attributes` array:

```json
{
  "resourceSpans": [
    {
      "resource": {
        "attributes": [
          {
            "key": "service.name",
            "value": { "stringValue": "quickpizza-ios" }
          },
          { "key": "service.version", "value": { "stringValue": "1.0.0" } }
        ]
      },
      "scopeSpans": [
        {
          "spans": [
            {
              "name": "pizza.get_recommendation",
              "kind": "SPAN_KIND_CLIENT",
              "attributes": [
                {
                  "key": "session.id",
                  "value": {
                    "stringValue": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
                  }
                },
                {
                  "key": "session.previous_id",
                  "value": {
                    "stringValue": "X9Y8Z7W6-V5U4-3210-FEDC-BA9876543210"
                  }
                },
                { "key": "pizza.vegetarian", "value": { "boolValue": true } }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

And every log record:

```json
{
  "resourceLogs": [
    {
      "resource": { "attributes": ["..."] },
      "scopeLogs": [
        {
          "logRecords": [
            {
              "body": { "stringValue": "Login successful" },
              "attributes": [
                {
                  "key": "session.id",
                  "value": {
                    "stringValue": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"
                  }
                },
                {
                  "key": "session.previous_id",
                  "value": {
                    "stringValue": "X9Y8Z7W6-V5U4-3210-FEDC-BA9876543210"
                  }
                },
                { "key": "username", "value": { "stringValue": "chef42" } }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

### Attribute key values (from opentelemetry-swift-core)

Defined in `SemanticConventions.Session` enum (`Session_attributes.swift`):

| Swift enum case                          | Raw string value        |
| ---------------------------------------- | ----------------------- |
| `SemanticConventions.Session.id`         | `"session.id"`          |
| `SemanticConventions.Session.previousId` | `"session.previous_id"` |

### What this means for Grafana Cloud / Loki queries

Since session.id is a **span/log attribute** (not a resource attribute), when querying in Loki or Tempo:

- In **Loki**: session.id would appear as a label or structured metadata field on each log line
- In **Tempo**: session.id would be a searchable span attribute
- You can **group/filter by session.id** to see all telemetry from a single user session
- You can **join session.previous_id** to trace session continuity across rotations

---

## Official OTel Session Specification

**Source**: [opentelemetry.io/docs/specs/semconv/general/session/](https://opentelemetry.io/docs/specs/semconv/general/session/)  
**Status**: **Development** (not yet stable)

### OTel's Definition of a Session

> "Session is defined as the period of time encompassing all activities performed by the application and the actions executed by the end user."
>
> "A Session is represented as a collection of Logs, Events, and Spans emitted by the Client Application throughout the Session's duration. Each Session is assigned a unique identifier, which is included as an attribute in the Logs, Events, and Spans generated during the Session's lifecycle."

Key points from the spec:

- Sessions are **attribute-based** — every span and log gets a `session.id` attribute
- Sessions are NOT represented as a resource; they're per-signal attributes
- The spec is **intentionally vague** about timeout/expiry rules — it says "typically due to user inactivity or session timeout" but **does not prescribe specific durations or rules**
- The spec defines two events: `session.start` and `session.end`
- `session.previous_id` enables **session linking** across rotations

### What the spec does NOT define

The OTel spec deliberately leaves these decisions to the implementer:

- **No prescribed timeout values** (no "must be 30 minutes" or "must be 15 minutes")
- **No max session duration** concept
- **No rules about app launch behavior** (new session vs. continue)
- **No rules about backgrounding** (mobile-specific)

This means: the Faro rules (15min inactivity, 4hr max, fresh on launch) are **a valid implementation** of the OTel session concept, just a more opinionated one. The OTel SDK's default (30min sliding window, persist across restarts) is also a valid implementation. Neither violates the spec.

### Requirement levels

| Attribute             | Requirement Level                                                                                        |
| --------------------- | -------------------------------------------------------------------------------------------------------- |
| `session.id`          | **Opt-In** (not required by default)                                                                     |
| `session.previous_id` | **Opt-In** / **Conditionally Required** (required on `session.start` if continuing from a prior session) |

### Session start event semantics

The spec has an interesting detail: if a `session.start` event contains both `session.id` AND `session.previous_id`, consumers SHOULD treat it as semantically equivalent to:

1. `session.end(session.previous_id)` — implicitly ending the old session
2. `session.start(session.id)` — starting the new one

This means you don't strictly need to emit `session.end` events if you always include `session.previous_id` on `session.start`.

---

## References

- [OTel Session Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/general/session/)
- [OTel Semantic Conventions Registry — Session Attributes](https://opentelemetry.io/docs/specs/semconv/registry/attributes/session/)
- OTel Swift SDK Sessions source: `opentelemetry-swift/Sources/Instrumentation/Sessions/`
- OTel Swift SDK Semantic Constants: `opentelemetry-swift-core/.../SemanticAttributes/Attributes/Session_attributes.swift`
- Current iOS OTel setup: `Mobiles/ios/QuickPizzaIos/Core/O11y/OTelService.swift`
