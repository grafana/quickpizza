# Shared mobile E2E tests (Arbigent)

End-to-end tests for the four QuickPizza mobile demo apps
(`Mobiles/flutter`, `Mobiles/react-native`, `Mobiles/android`,
`Mobiles/ios`) all live here so we maintain one runner script, one
scenario template, and one HTML report generator.

Tests are driven by [Arbigent](https://github.com/takahirom/arbigent),
which uses an LLM (OpenAI by default) to interact with the app through
the platform's accessibility tree. A single scenario file walks the AI
through the canonical QuickPizza flow: open the app, log in, request a
pizza recommendation, rate it, background the app, and bring it back.

## Layout

```
Mobiles/e2e/
├── run_e2e_tests.sh                              # Unified runner (all apps, all platforms)
├── arbigent-e2e_basic_pizza_flow.yaml.template   # Shared scenario template (currently Android-only)
├── arbigent-recovery-hints.txt                   # Shared "if stuck" guidance, injected into every scenario goal
├── render-template.js                            # Renders the template (placeholders + recovery block) into a runnable YAML
├── report-generator/                             # HTML report tool (separate npm package)
│   ├── generate_report.js
│   ├── package.json
│   ├── package-lock.json
│   ├── .npmrc / .yarnrc / .yarnrc.yml            # ignore install scripts; engine-strict
└── results/                                      # Test artifacts land here (git-ignored)
    └── <app>/
        ├── arbigent-project.yaml                 # Rendered scenario file (template + per-app values)
        ├── arbigent-result/                      # Latest run output + visual_report.html
        ├── arbigent-result-N/                    # Archived previous runs
        └── arbigent-cache/                       # AI response cache (speeds up repeat runs)
```

Centralising results under `Mobiles/e2e/results/` keeps the per-app
directories (`Mobiles/flutter/`, etc.) clean and avoids each app having
its own `arbigent-result/` and `arbigent-cache/` directories.

## Quick start (local)

Prerequisites:
- An Android emulator booted, with the app under test installed.
- QuickPizza backend running and reachable at `http://localhost:3333`.
  For Android emulators, also run `adb reverse tcp:3333 tcp:3333`.
- `OPENAI_API_KEY` exported.
- `adb`, `unzip`, `node` (18+), `npm`, and either `wget` or `curl` available.

```bash
# From repo root
export OPENAI_API_KEY='sk-...'

# Flutter on Android
./Mobiles/e2e/run_e2e_tests.sh --app=flutter --platform=android

# React Native on Android — see the RN note below first
./Mobiles/e2e/run_e2e_tests.sh --app=react-native --platform=android

# Native Android (Kotlin / Compose)
./Mobiles/e2e/run_e2e_tests.sh --app=android-native --platform=android
```

### Extra step for local React Native runs

If you installed the RN app locally via `yarn android` (the normal dev
workflow), the APK does NOT have the JS bundle embedded — it expects
Metro to serve the bundle at runtime. Before running the e2e tests:

```bash
# In a separate terminal, leave running
cd Mobiles/react-native && yarn start

# Tell the emulator to find Metro and the backend on the host
adb reverse tcp:8081 tcp:8081
adb reverse tcp:3333 tcp:3333
```

This does NOT apply in CI: the
[`mobile_demo_telemetry.yaml`](../../.github/workflows/mobile_demo_telemetry.yaml)
workflow runs `npx react-native bundle` before `./gradlew assembleDebug`,
which produces an **offline** debug APK (JS embedded at
`assets/index.android.bundle`) that doesn't talk to Metro at all. The
runner script intentionally doesn't try to manage Metro itself —
spawning a long-running dev server from a test runner is fragile, and
most local users will have Metro running already while iterating on the
app.

Results land in `Mobiles/e2e/results/<app>/arbigent-result/` (e.g.
`Mobiles/e2e/results/flutter/arbigent-result/`). The HTML report is at
`arbigent-result/visual_report.html`. Previous runs are archived as
`arbigent-result-1/`, `arbigent-result-2/`, etc. The `arbigent-cache/`
directory holds Arbigent's AI response cache and is reused across
runs to save time and OpenAI cost when the UI tree + goal are
unchanged. The rendered project file (`arbigent-project.yaml`) is
written there too so you can inspect exactly what Arbigent was asked
to do — the runner reads the template, substitutes per-app values,
and persists the result alongside the run output (gitignored).

## Supported combinations

| App            | Android | iOS | Status                                 |
| -------------- | :-----: | :-: | -------------------------------------- |
| flutter        |   yes   |  -  | active                                 |
| react-native   |   yes   |  -  | active                                 |
| android-native |   yes   |  -  | active                                 |
| ios-native     |    -    |  -  | planned (Phase 3 of the e2e refactor)  |
| flutter (iOS)  |    -    |  -  | planned (Phase 4 of the e2e refactor)  |
| RN (iOS)       |    -    |  -  | planned (Phase 4 of the e2e refactor)  |

iOS will land in later phases — `--platform=ios` currently exits with a
clear error pointing at the refactor plan.

## Configuration knobs

The runner reads these environment variables (all optional except
`OPENAI_API_KEY`):

| Variable                 | Default                 | Purpose                                            |
| ------------------------ | ----------------------- | -------------------------------------------------- |
| `OPENAI_API_KEY`         | _(required)_            | Passed to Arbigent for AI decisions.               |
| `ARBIGENT_VERSION`       | `0.72.0`                | Arbigent CLI release to download.                  |
| `ARBIGENT_MODEL`         | `gpt-5.2`               | OpenAI model used by Arbigent.                     |
| `ARBIGENT_LOG_AI_API`    | `false`                 | Set `true` to log AI API request/response payloads (system prompt, per-step prompts). |
| `QUICKPIZZA_BACKEND_URL` | `http://localhost:3333` | Backend reachability probe before launching tests. |

## Scenario template

The scenario goals live in
[`arbigent-e2e_basic_pizza_flow.yaml.template`](./arbigent-e2e_basic_pizza_flow.yaml.template).
The runner substitutes three tokens before handing the file to
Arbigent:

| Token                  | Replaced with                                                              |
| ---------------------- | -------------------------------------------------------------------------- |
| `__ANDROID_PACKAGE__`  | Android package id of the app under test (e.g. `com.example.flutter_…`).   |
| `__IOS_BUNDLE_ID__`    | iOS bundle id (currently unused; will be filled in once iOS lands).        |
| `__RECOVERY_BLOCK__`   | Contents of [`arbigent-recovery-hints.txt`](./arbigent-recovery-hints.txt), indented to match the YAML block-scalar context. |

The recovery block is short, app-agnostic guidance the AI should fall
back on when it cannot make progress — dismiss unexpected modals, scroll
when an expected element is missing, wait once when a tap seems to have
been ignored, etc. It's kept in a separate file so we have a single
source of truth (one edit updates all five scenarios) and so we can
iterate on prompt content without touching scenario flows. The block is
injected at the END of each scenario goal so the scenario-specific
guidance is read first.

In Phase 3 of the refactor the template will split into
`*.android.yaml.template` and `*.ios.yaml.template` since the launcher
and backgrounding flows differ enough between OSes to make a single
template unreliable.

## CI

The hourly workflow at
[`.github/workflows/mobile_demo_telemetry.yaml`](../../.github/workflows/mobile_demo_telemetry.yaml)
builds the APKs, boots a single Android emulator, and runs each app's
e2e flow sequentially on the same emulator (Flutter → React Native →
Android Native). Phases 3–5 will add native iOS and the iOS variants
of Flutter / React Native.
