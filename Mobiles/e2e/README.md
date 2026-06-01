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
├── run_e2e_tests.sh                                       # Unified runner (all apps, all platforms)
├── arbigent-e2e_basic_pizza_flow.android.yaml.template    # Android scenario template (Flutter + RN + native Android)
├── arbigent-e2e_basic_pizza_flow.ios.yaml.template        # iOS scenario template (native iOS today; Flutter/RN on iOS later)
├── arbigent-recovery-hints.txt                            # Shared "if stuck" guidance, injected into every scenario goal
├── render-template.js                                     # Renders a template (placeholders + recovery block) into a runnable YAML
├── report-generator/                                      # HTML report tool (separate npm package)
│   ├── generate_report.js
│   ├── package.json
│   ├── package-lock.json
│   ├── .npmrc / .yarnrc / .yarnrc.yml                     # ignore install scripts; engine-strict
└── results/                                               # Test artifacts land here (git-ignored)
    └── <app>/
        ├── arbigent-project.yaml                          # Rendered scenario file (template + per-app values)
        ├── arbigent-result/                               # Latest run output + visual_report.html
        │   ├── arbigent-project.yaml                      # Copy of the rendered YAML used for the latest run
        │   └── arbigent-result-N/                         # Archived run, including its own arbigent-project.yaml
        └── arbigent-cache/                                # AI response cache (speeds up repeat runs)
```

Centralising results under `Mobiles/e2e/results/` keeps the per-app
directories (`Mobiles/flutter/`, etc.) clean and avoids each app having
its own `arbigent-result/` and `arbigent-cache/` directories.

## Quick start (local)

Prerequisites (Android):
- An Android emulator booted, with the app under test installed.
- QuickPizza backend running and reachable at `http://localhost:3333`.
  For Android emulators, also run `adb reverse tcp:3333 tcp:3333`.
- `OPENAI_API_KEY` exported.
- `adb`, `unzip`, Node.js 24.5+, npm 11.10+, and either `wget` or `curl` available.

Prerequisites (iOS — macOS only):
- Xcode + Command Line Tools (`xcrun`, `xcodebuild`).
- A booted iOS simulator with the iOS app already installed
  (e.g. `bash Mobiles/ios/Scripts/sim-run.sh` — it builds, boots, and
  installs in one go, then you can `Ctrl+C` out of the log stream).
- QuickPizza backend on `http://localhost:3333` (the simulator shares the
  Mac's network, so no port forwarding is required).
- `OPENAI_API_KEY` exported. `xcrun`, `unzip`, Node.js 24.5+, npm 11.10+, and
  either `wget` or `curl` available.

```bash
# From repo root
export OPENAI_API_KEY='sk-...'

# Flutter on Android
./Mobiles/e2e/run_e2e_tests.sh --app=flutter --platform=android

# React Native on Android — see the RN note below first
./Mobiles/e2e/run_e2e_tests.sh --app=react-native --platform=android

# Native Android (Kotlin / Compose)
./Mobiles/e2e/run_e2e_tests.sh --app=android-native --platform=android

# Native iOS (Swift / SwiftUI) — macOS only
./Mobiles/e2e/run_e2e_tests.sh --app=ios-native --platform=ios
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
workflow runs `yarn react-native bundle` before `./gradlew assembleDebug`,
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
written both at the app result root and inside the latest/archived
result output so you can inspect exactly what Arbigent was asked to do
for the report you're viewing — the runner reads the template,
substitutes per-app values, and persists the result alongside the run
output (gitignored).

## Supported combinations

| App            | Android | iOS | Status                                 |
| -------------- | :-----: | :-: | -------------------------------------- |
| flutter        |   yes   |  -  | active                                 |
| react-native   |   yes   |  -  | active                                 |
| android-native |   yes   |  -  | active                                 |
| ios-native     |    -    | yes | active (macOS only — Xcode required)   |
| flutter (iOS)  |    -    |  -  | planned                                |
| RN (iOS)       |    -    |  -  | planned                                |

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

## Scenario templates

The scenario goals live in two parallel templates, one per platform:

- [`arbigent-e2e_basic_pizza_flow.android.yaml.template`](./arbigent-e2e_basic_pizza_flow.android.yaml.template) — Flutter, React Native, and native Android on a running Android emulator.
- [`arbigent-e2e_basic_pizza_flow.ios.yaml.template`](./arbigent-e2e_basic_pizza_flow.ios.yaml.template) — native iOS (and later Flutter/RN on iOS) on a running iOS simulator.

The split exists because launcher and backgrounding flows differ enough
between Springboard and the Android launcher that a single template was
fragile: HOME is a hardware key on Android but an XCUITest call on iOS,
and the "find the app icon and tap it" fallback prose mentions
platform-specific app names (Play Store / Gmail vs. Safari / Messages).

The runner substitutes three tokens before handing the file to Arbigent:

| Token                  | Replaced with                                                                  |
| ---------------------- | ------------------------------------------------------------------------------ |
| `__ANDROID_PACKAGE__`  | Android package id of the app under test (used in the `.android` template).    |
| `__IOS_BUNDLE_ID__`    | iOS bundle id of the app under test (used in the `.ios` template).             |
| `__RECOVERY_BLOCK__`   | Contents of [`arbigent-recovery-hints.txt`](./arbigent-recovery-hints.txt), indented to match the YAML block-scalar context. |

The recovery block is short, app- and platform-agnostic guidance the AI
should fall back on when it cannot make progress — dismiss unexpected
modals, scroll when an expected element is missing, wait once when a tap
seems to have been ignored, etc. It's kept in a separate file so we have
a single source of truth (one edit updates both templates' five
scenarios each) and so we can iterate on prompt content without touching
scenario flows. The block is injected at the END of each scenario goal
so the scenario-specific guidance is read first.

## CI

Two workflows cover mobile telemetry — **PR builds never fetch Vault secrets**.

| Workflow | Trigger | Vault | Purpose |
| -------- | ------- | ----- | ------- |
| [`mobile_demo_telemetry_build.yaml`](../../.github/workflows/mobile_demo_telemetry_build.yaml) | `pull_request` (mobile jobs skip when unrelated paths change) | No | Compile-only check with placeholder telemetry config |
| [`mobile_demo_telemetry.yaml`](../../.github/workflows/mobile_demo_telemetry.yaml) | `schedule`, `workflow_dispatch`, `push` to `main` | Yes | Full build + e2e + Grafana Cloud telemetry |

**After opening a mobile PR:** wait for the four **Build check — …** jobs in *Mobile Demo Telemetry (build only)*.

**Full Cloud telemetry before merge:** run **Mobile Demo Telemetry** manually via Actions → *Run workflow* on your branch (`workflow_dispatch`), or rely on the hourly schedule / post-merge run on `main`.

The full telemetry workflow has two independent legs that run in parallel:

- **Android leg** — `ubuntu-latest`. Builds the Flutter, React Native,
  and native Android APKs (credentials from Vault at build time), uploads
  each APK as a run-scoped Actions artifact (`retention-days: 1`), and
  the e2e job downloads them within the same workflow run — artifacts are
  not restorable from PR workflows the way branch-scoped caches are.
  Boots a single Android emulator; installs each APK in turn and runs
  `run_e2e_tests.sh --platform=android` for each app.
- **iOS leg** — `macos-26`. Builds the native iOS `.app` (Vault creds at
  build time), uploads it as a run-scoped artifact for the e2e job in
  the same workflow run, boots an iOS simulator, installs the app, and
  runs `run_e2e_tests.sh --app=ios-native --platform=ios`. The QuickPizza
  backend is started natively on the macOS runner.

The iOS variants of Flutter and React Native will be added later by
plugging their respective .app builds into the iOS leg.
