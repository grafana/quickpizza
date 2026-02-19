# TODO: iOS OTel & Testing Ideas

Backlog of things to explore for the iOS app. Tackle one at a time — create a
dedicated plan file (like `PLAN-crash-reporting-metrickit-otel.md`) when diving deeper.

---

## Sessions
Investigate if `opentelemetry-swift` has built-in session support (e.g. via
`ResourceExtension`) or if we need to generate a `session.id` ourselves. Check
what attribute name Grafana App O11y expects for session grouping.

## Metrics
We currently have traces and logs but no `MeterProvider`. Find out what metrics
(if any) `URLSessionInstrumentation` emits out of the box, and whether it's
worth setting up client-side metrics or relying on span-derived metrics
server-side (Tempo/Collector).

## View Transitions
Explore options for capturing screen navigation as spans. SwiftUI lacks UIKit's
lifecycle hooks, so likely needs a custom `ViewModifier` (`onAppear`/`onDisappear`)
or observing `NavigationPath` changes in `MainShellViewModel`. Check if the
Swift OTel SDK has anything built-in.

## User Context
Figure out how to attach user identity (`enduser.id`) to telemetry after login.
Options: per-span attributes, or a custom `SpanProcessor` that auto-injects user
info. Also consider emitting user lifecycle events (login/logout) as OTel logs.

## iOS E2E AI Testing
Set up a GitHub Actions workflow for iOS e2e testing, mirroring the existing
Flutter/Android pipeline (`mobile_demo_telemetry.yaml`). Key challenges: macOS
runners (expensive), Xcode build on CI, choosing an AI testing framework
(Maestro, Arbigent, or custom `xcrun simctl` + screenshots + OpenAI).
