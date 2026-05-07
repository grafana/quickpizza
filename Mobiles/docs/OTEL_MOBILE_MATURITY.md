# OTel Mobile Maturity Log

A living log of rough edges, gaps, and contribution opportunities we hit while
using `opentelemetry-swift`, `opentelemetry-android`, and the related contrib
packages in the QuickPizza mobile demo apps.

The point of this file is **not** to complain about the SDKs — they are
genuinely useful and we use them on purpose. The point is to capture concrete,
reproducible friction so that:

1. Future demo work has a list of "things that hurt last time, watch out."
2. We have evidence to drive **upstream contributions** instead of forking. Each
   entry is a candidate issue / PR / RFC against the corresponding upstream
   project.
3. SEs and customers asking "is OTel mobile mature enough for us?" get an
   honest, current answer instead of a marketing one.

Faro mobile SDK quirks live in the per-platform READMEs and in the
[overview's "Known issues" section](./MOBILE_OBSERVABILITY_OVERVIEW.md#known-issues--open-questions).
This file is OTel-mobile-specific.

## Entry format

Each entry has a stable ID (`M-NNN`) so issues, PRs, and commits can reference
it. New entries are appended — do not renumber existing ones.

```
### M-NNN — Short title

- **Status:** open | needs-verification | upstreamed | resolved
- **Category:** missing-capability | awkward-api | bug | docs-gap
- **Severity:** low | medium | high
- **SDKs affected:** opentelemetry-swift, opentelemetry-android, ...
- **Demo apps affected:** iOS native, Android native, ...
- **First seen:** YYYY-MM-DD

**What we wanted to do**
[concrete user-story-shaped sentence]

**What actually happened / what's missing**
[the gap]

**Workaround in this demo (if any)**
[code pointer or "none yet"]

**What we'd want upstream**
[shape of the proposed change — be specific]

**Tracking**
- Internal: #N
- Upstream: <link or TBD>
```

---

## Entries

### M-001 — No first-class user context (`enduser.id`) on mobile SDKs

- **Status:** open
- **Category:** missing-capability
- **Severity:** medium
- **SDKs affected:** `opentelemetry-swift`, `opentelemetry-android`
- **Demo apps affected:** iOS native, Android native
- **First seen:** 2026-05-06

**What we wanted to do**

After login, attach the application user id (`enduser.id` per OTel SemConv) to
**every** span and log record the SDK produces, so dashboards can slice
telemetry by user — the same way the Faro mobile SDKs do automatically via
`Faro.setUserMeta(...)`.

**What actually happened / what's missing**

Neither `opentelemetry-swift` nor the `opentelemetry-android` RUM agent has a
built-in concept of "current end-user" that can be enriched onto every signal.
The OTel SemConv defines `enduser.*`
([docs](https://opentelemetry.io/docs/specs/semconv/registry/attributes/enduser/))
but stamping it on signals is left entirely to the application — including the
non-obvious bit that it must be attached **per-signal via processors**, not as
a Resource attribute (resources are immutable for the lifetime of the SDK,
which doesn't fit "user logs in/out at runtime").

This is the same shape as `session.id`, which the SDKs *do* solve via the
`Sessions` library on iOS and the RUM agent on Android. So the precedent for
"per-signal mutable context" exists — user context is the obvious next one.

**Workaround in this demo (if any)**

None yet. We currently set `enduser.id` only on the manual `auth.login` span
and nowhere else, leaving the rest of the telemetry user-anonymous.

**What we'd want upstream**

A small, opt-in user-context library analogous to `Sessions`:

- `UserContextHolder` (or similar) — thread-safe holder for current user id +
  optional pseudo id and full name. Set/cleared by app code on login/logout.
- A pre-built `SpanProcessor` and `LogRecordProcessor` pair that read from the
  holder and stamp `enduser.id` on `onStart` / `onEmit`.
- PII-conscious defaults (recommend `enduser.pseudo.id` over raw username).

Most likely lives in `opentelemetry-swift-contrib` first (where `Sessions` and
`MetricKitInstrumentation` live), then promoted later if it earns its keep.

**Tracking**

- Internal: [#48](https://github.com/grafana/mobile-o11y-demo/issues/48)
- Upstream: TBD — open after we've shipped the in-app version and know the API
  shape we want.

---

### M-002 — No first-class OTel Metrics support on mobile

- **Status:** open
- **Category:** missing-capability
- **Severity:** medium-low (workarounds via logs/spans exist)
- **SDKs affected:** `opentelemetry-swift`, `opentelemetry-android`
- **Demo apps affected:** iOS native, Android native
- **First seen:** 2026-05-06

**What we wanted to do**

Emit application metrics (counters, histograms — e.g. "pizza recommendations
requested", "checkout latency distribution") via the OTel Metrics SDK so they
land in Mimir / Prometheus and show up alongside our infra metrics.

**What actually happened / what's missing**

`opentelemetry-swift` does not currently ship a stable Metrics SDK; the iOS
demo uses logs + spans only. `opentelemetry-android` has metrics support in
its core dependencies, but the RUM agent's surface area for "give me a
`MeterProvider`" is awkward and we haven't wired it.

Net effect: there is no `MeterProvider` in either native demo app, and "rate of
checkouts" today has to be computed from log lines or spans rather than from a
counter. That works, but is the wrong shape.

**Workaround in this demo (if any)**

For Faro Flutter, we use `kind=measurement` Faro signals — which arrive as
Loki logs, not as Prometheus metrics, so they're queryable but not aggregatable
the way real metrics are. RN/iOS/Android currently emit no metric-shaped data
at all.

**What we'd want upstream**

- `opentelemetry-swift` to ship a Metrics SDK that meets OTel Metrics spec
  parity. Track upstream progress; do not roll our own.
- `opentelemetry-android` to expose a documented, stable `MeterProvider`
  accessor on the RUM agent, so apps don't have to bypass the agent to add
  metrics.

**Tracking**

- Internal: TBD
- Upstream: TBD — re-evaluate quarterly; this is mostly waiting on upstream
  rather than something we should drive ourselves.

---

### M-003 — Android RUM agent's processor extensibility (needs verification)

- **Status:** needs-verification
- **Category:** awkward-api (suspected)
- **Severity:** unknown until verified
- **SDKs affected:** `opentelemetry-android` (the RUM agent specifically)
- **Demo apps affected:** Android native
- **First seen:** 2026-05-06

**What we wanted to do**

Register a custom `SpanProcessor` and `LogRecordProcessor` on the RUM agent
without bypassing it (so we keep the agent's auto-instrumentation: HTTP,
lifecycle, jank, ANR, crash).

**What actually happened / what's missing**

`OpenTelemetryRumInitializer` (the facade most apps use) appears to take a
single fluent-builder configuration. It is not yet clear whether this builder
exposes hooks for adding custom span / log processors, or whether you have to
construct the underlying `SdkTracerProvider` / `SdkLoggerProvider` yourself
and lose the agent's auto-instrumentation in the process.

This needs to be checked before #48 can be implemented on Android.

**Workaround in this demo (if any)**

None — we haven't tried yet. If the answer is "you have to build providers
manually," that's the entry-worthy maturity gap. If the answer is "yes, here's
the hook," this entry resolves to "docs gap, link the API."

**What we'd want upstream (if confirmed)**

A documented public API on `OpenTelemetryRumInitializer` (or its replacement)
to attach additional `SpanProcessor` / `LogRecordProcessor` instances without
having to re-wire the agent's internals. A minimal change of the shape:

```kotlin
OpenTelemetryRumInitializer.builder(...)
    .addSpanProcessor(myProcessor)
    .addLogRecordProcessor(myLogProcessor)
    ...
    .build()
```

**Tracking**

- Internal: blocks part of [#48](https://github.com/grafana/mobile-o11y-demo/issues/48)
- Upstream: TBD — verify the API surface first, then file an issue against
  `opentelemetry-android` if needed.

---

### M-004 — Screen / view transitions are not captured as spans

- **Status:** open
- **Category:** missing-capability (with iOS/Android asymmetry)
- **Severity:** low (workarounds exist; we already emit `screen.view`-shaped
  signals)
- **SDKs affected:** `opentelemetry-swift` (no screen detection at all),
  `opentelemetry-android` RUM agent (emits `screen.view` log events but not
  spans)
- **Demo apps affected:** iOS native, Android native
- **First seen:** 2026-05-06

**What we wanted to do**

Capture each screen the user visits as a **span**, with start / end / duration,
parented to the user's session. Then a "time spent per screen" panel falls
out of Tempo for free, and slow screens surface naturally as long-duration
spans rather than having to be reconstructed from log timestamps.

**What actually happened / what's missing**

- `opentelemetry-swift`: no screen / view-transition instrumentation at all.
  SwiftUI lacks UIKit's view-controller lifecycle hooks, so there is no
  obvious place for the SDK to even hang an instrumentation off. The demo's
  `app.screen.view` events are entirely manual.
- `opentelemetry-android`: the RUM agent does detect screen views and emits
  them as `event_name=screen.view` log records (visible in our telemetry
  inventory). That is useful but it is not a span — there is no duration,
  no parent / child relationship to user actions on that screen, no Tempo
  drilldown.

So we have an **asymmetry**: Android gives us screen detection (as logs only),
iOS gives us nothing.

**Workaround in this demo (if any)**

iOS: emit a manual `app.screen.view` log record from a `ViewModifier`
attached to each top-level screen. Android: rely on the RUM agent's auto
`screen.view` events. Neither produces spans.

A more thorough workaround would be a custom `ViewModifier` that calls
`onAppear` to start a span and `onDisappear` to end it — at the cost of
boilerplate on every screen. We have not implemented this.

**What we'd want upstream**

- `opentelemetry-swift` (or contrib): a SwiftUI screen-tracking module that
  uses `ViewModifier`s to emit a span per screen-presentation. Probably needs
  to be opt-in per screen (or a single `.trackedAsScreen("name")` modifier)
  rather than fully automatic, since SwiftUI views are too granular to
  treat every body re-render as a screen.
- `opentelemetry-android` RUM agent: complement the existing `screen.view`
  log events with a span variant (or convert the log to a span). The agent
  already knows when the user enters / exits a screen — emitting a span
  for that interval is a small step.

**Tracking**

- Internal: TBD (this entry; promote to a GitHub issue if/when we decide to
  implement the demo-side workaround)
- Upstream: TBD

---

## How to add a new entry

1. Pick the next free `M-NNN` (do not reuse / renumber).
2. Use the template at the top of this file.
3. Be concrete: link to file:line, an upstream issue, a `gcx` query — anything
   that lets a future reader reproduce what you saw.
4. If you don't yet know whether something is a real gap, file it with status
   `needs-verification` rather than dropping it. The verification is worth as
   much as the entry itself.
5. When an entry resolves (upstream PR merged, in-app workaround obsoleted,
   etc.), set the status to `resolved` or `upstreamed` — do **not** delete
   it. The history of "things we hit and how they got fixed" is the most
   useful part of this file long-term.
