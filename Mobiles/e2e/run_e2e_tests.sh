#!/bin/bash
# Unified Arbigent E2E runner for the QuickPizza mobile demo apps.
#
# Replaces the per-app scripts that previously lived at:
#   - Mobiles/flutter/scripts/e2e/run_e2e_tests.sh
#   - Mobiles/react-native/scripts/e2e/run_e2e_tests.sh
#
# Usage:
#   ./Mobiles/e2e/run_e2e_tests.sh --app=flutter         --platform=android
#   ./Mobiles/e2e/run_e2e_tests.sh --app=react-native    --platform=android
#   ./Mobiles/e2e/run_e2e_tests.sh --app=android-native  --platform=android
#   ./Mobiles/e2e/run_e2e_tests.sh --app=ios-native      --platform=ios
#
# Future phases will add:
#   --app=flutter          --platform=ios
#   --app=react-native     --platform=ios
#
# Required env vars:
#   OPENAI_API_KEY    OpenAI API key used by Arbigent.
#
# Optional env vars:
#   ARBIGENT_VERSION         Arbigent CLI version to download (default: 0.72.0).
#   ARBIGENT_MODEL           OpenAI model name passed to Arbigent (default: gpt-5.2).
#   ARBIGENT_LOG_AI_API      When 'true', appends --ai-api-logging to Arbigent so the
#                            full AI API request/response payloads are logged. Off by
#                            default since it dramatically increases log volume.
#                            Useful for inspecting the system prompt + per-step prompts.
#   QUICKPIZZA_BACKEND_URL   Backend reachability probe (default: http://localhost:3333).

set -e

### Configuration #############################################################

ARBIGENT_VERSION="${ARBIGENT_VERSION:-0.72.0}"
ARBIGENT_MODEL="${ARBIGENT_MODEL:-gpt-5.2}"
ARBIGENT_LOG_AI_API="${ARBIGENT_LOG_AI_API:-false}"
ARBIGENT_DOWNLOAD_URL="https://github.com/takahirom/arbigent/releases/download/${ARBIGENT_VERSION}/arbigent-${ARBIGENT_VERSION}.zip"
ARBIGENT_DIR="/tmp/arbigent-${ARBIGENT_VERSION}"
DEFAULT_BACKEND_URL="http://localhost:3333"

### Paths #####################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
MOBILES_ROOT="$(cd "$SCRIPT_DIR/.." &> /dev/null && pwd)"
REPO_ROOT="$(cd "$MOBILES_ROOT/.." &> /dev/null && pwd)"
REPORT_DIR="$SCRIPT_DIR/report-generator"
RESULTS_ROOT="$SCRIPT_DIR/results"
# Platform-specific scenario templates live next to this script. The Android
# template covers Flutter/RN/Native on Android; the iOS template covers
# native iOS (and Flutter/RN on iOS once those phases land). The runner picks
# the file based on --platform; see render_template().
TEMPLATE_FILE_ANDROID="$SCRIPT_DIR/arbigent-e2e_basic_pizza_flow.android.yaml.template"
TEMPLATE_FILE_IOS="$SCRIPT_DIR/arbigent-e2e_basic_pizza_flow.ios.yaml.template"
RECOVERY_HINTS_FILE="$SCRIPT_DIR/arbigent-recovery-hints.txt"
RENDER_HELPER="$SCRIPT_DIR/render-template.js"

### Output helpers ############################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${GREEN}===> $1${NC}"
}

print_skip() {
    echo -e "${YELLOW}SKIP: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

### Cleanup handlers ##########################################################

cleanup_arbigent_processes() {
    local java_pids
    java_pids=$(ps aux | grep -i java | grep -v grep | awk '{print $2}')
    if [ -n "$java_pids" ]; then
        for pid in $java_pids; do
            if ps -p "$pid" -o command= 2>/dev/null | grep -q -i "arbigent\|maestro\|dadb"; then
                echo "Killing Arbigent-related Java process: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    local arbigent_pids
    arbigent_pids=$(ps aux | grep -i arbigent | grep -v grep | awk '{print $2}')
    if [ -n "$arbigent_pids" ]; then
        echo "Killing Arbigent processes: $arbigent_pids"
        # shellcheck disable=SC2086
        kill -9 $arbigent_pids 2>/dev/null || true
    fi
}

cleanup_on_exit() {
    echo "" >&2
    print_skip "Script interrupted, cleaning up..."
    cleanup_arbigent_processes
    if [ "$PLATFORM" = "android" ]; then
        adb forward --remove-all 2>/dev/null || true
    fi
    exit 1
}

trap cleanup_on_exit INT TERM QUIT

### Arg parsing ###############################################################

APP=""
PLATFORM=""

show_help() {
    cat <<EOF
QuickPizza mobile E2E runner (Arbigent)

Usage: $0 --app=<app> --platform=<platform>

Required:
  --app=<flutter|react-native|android-native|ios-native>   App under test
  --platform=<android|ios>                                 Target platform

Other:
  -h, --help                                               Show this help message

Examples:
  bash $0 --app=flutter --platform=android
  bash $0 --app=react-native --platform=android
  bash $0 --app=android-native --platform=android
  bash $0 --app=ios-native --platform=ios

Required env vars:
  OPENAI_API_KEY                    OpenAI key used by Arbigent

Optional env vars:
  ARBIGENT_VERSION       (default 0.72.0)
  ARBIGENT_MODEL         (default gpt-5.2)
  ARBIGENT_LOG_AI_API    (default false) — set 'true' to log AI API payloads
  QUICKPIZZA_BACKEND_URL (default http://localhost:3333)
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --app=*)      APP="${1#--app=}"; shift ;;
        --app)        APP="$2"; shift 2 ;;
        --platform=*) PLATFORM="${1#--platform=}"; shift ;;
        --platform)   PLATFORM="$2"; shift 2 ;;
        -h|--help)    show_help; exit 0 ;;
        *)            echo "Unknown option: $1" >&2; show_help; exit 1 ;;
    esac
done

[ -n "$APP" ]      || { show_help; print_error "--app is required"; }
[ -n "$PLATFORM" ] || { show_help; print_error "--platform is required"; }

### App configuration table ###################################################
# Add new apps here as later phases bring them online (native android,
# native ios, plus iOS variants of Flutter and RN).

ANDROID_PACKAGE=""
IOS_BUNDLE_ID=""

case "$APP" in
    flutter)
        ANDROID_PACKAGE="com.example.flutter_mobile_o11y_demo"
        IOS_BUNDLE_ID="com.example.flutterMobileO11yDemo"
        ;;
    react-native)
        ANDROID_PACKAGE="com.quickpizza"
        IOS_BUNDLE_ID="com.quickpizza"
        ;;
    android-native)
        ANDROID_PACKAGE="com.grafana.quickpizza"
        IOS_BUNDLE_ID=""
        ;;
    ios-native)
        ANDROID_PACKAGE=""
        IOS_BUNDLE_ID="com.grafana.QuickPizzaIos"
        ;;
    *)
        print_error "Unsupported --app=$APP (supported: flutter, react-native, android-native, ios-native). Flutter/RN on iOS land in later phases."
        ;;
esac

# All test artifacts (arbigent-result/, arbigent-cache/, archived runs)
# are written under Mobiles/e2e/results/<app>/ to keep the per-app
# directories clean and centralise e2e outputs in one place.
RESULTS_DIR="$RESULTS_ROOT/$APP"

case "$PLATFORM" in
    android)
        # Android currently runs Flutter, React Native, and native Android.
        if [ -z "$ANDROID_PACKAGE" ]; then
            print_error "--app=$APP has no Android package id; pass a different --platform."
        fi
        ;;
    ios)
        # iOS currently runs native iOS only; Flutter/RN on iOS land later.
        if [ "$APP" != "ios-native" ]; then
            print_error "--platform=ios currently only supports --app=ios-native (Flutter/RN on iOS land in later phases)."
        fi
        if [ -z "$IOS_BUNDLE_ID" ]; then
            print_error "--app=$APP has no iOS bundle id; pass a different --platform."
        fi
        ;;
    *)
        print_error "Unsupported --platform=$PLATFORM (supported: android, ios)"
        ;;
esac

### Dependency checks #########################################################

DOWNLOAD_CMD=""

check_dependencies() {
    print_step "Checking dependencies..."

    local required=(unzip)
    if [ "$PLATFORM" = "android" ]; then
        required+=(adb)
    fi
    if [ "$PLATFORM" = "ios" ]; then
        # Arbigent's iOS path runs Maestro's iOS driver, which shells out to
        # `xcrun simctl` for boot/install/launch. xcrun is shipped with Xcode
        # Command Line Tools; on macOS-only.
        required+=(xcrun)
    fi
    for cmd in "${required[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            print_error "$cmd is required but not installed"
        fi
    done

    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget"
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl"
    else
        print_error "Either wget or curl is required"
    fi

    if ! command -v node &> /dev/null; then
        print_error "node is required for HTML report generation (install Node.js >=18)"
    fi
    if ! command -v npm &> /dev/null; then
        print_error "npm is required to install the report generator's dependencies"
    fi
}

### Arbigent download #########################################################

download_arbigent() {
    if [ -d "$ARBIGENT_DIR" ]; then
        print_step "Arbigent v${ARBIGENT_VERSION} already present at $ARBIGENT_DIR"
        return 0
    fi

    print_step "Downloading Arbigent v${ARBIGENT_VERSION}..."
    local original_dir
    original_dir="$(pwd)"
    cd /tmp

    if [ "$DOWNLOAD_CMD" = "wget" ]; then
        wget -q "$ARBIGENT_DOWNLOAD_URL"
    else
        curl -sLO "$ARBIGENT_DOWNLOAD_URL"
    fi

    unzip -q "arbigent-${ARBIGENT_VERSION}.zip"
    chmod -R +x "arbigent-${ARBIGENT_VERSION}"
    rm -f "arbigent-${ARBIGENT_VERSION}.zip"
    cd "$original_dir"
    print_step "Arbigent downloaded successfully"
}

### Platform readiness ########################################################

check_backend() {
    local backend_url="${QUICKPIZZA_BACKEND_URL:-$DEFAULT_BACKEND_URL}"
    local backend_ready="${backend_url}/ready"
    print_step "Checking QuickPizza backend at $backend_url..."
    if curl -fsS --connect-timeout 5 "$backend_ready" > /dev/null 2>&1; then
        print_step "Backend is reachable"
    else
        print_error "QuickPizza backend not reachable at $backend_url. Ensure docker compose is up; for android emulators also run: adb reverse tcp:3333 tcp:3333"
    fi
}

check_android_emulator() {
    print_step "Checking Android emulator..."
    if ! adb devices | grep -q "emulator"; then
        print_error "No Android emulator found. Please start an emulator first."
    fi
    echo "Waiting for emulator to be fully booted..."
    adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done'
    print_step "Available devices:"
    adb devices -l
}

# Confirms a booted iOS simulator exists and that the app under test is
# already installed on it. We do NOT boot a simulator or install the .app
# here — that's the caller's job (Scripts/sim-run.sh locally, or an explicit
# "boot simulator + install app" step in CI). Keeping this script
# install-agnostic mirrors check_android_emulator and avoids hiding "I forgot
# to install the app" mistakes behind a silent reinstall.
check_ios_simulator() {
    print_step "Checking iOS simulator..."
    local booted_udid
    booted_udid=$(xcrun simctl list devices booted -j 2>/dev/null \
        | python3 -c '
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get("devices", {}).items():
    for d in devices:
        if d.get("state") == "Booted":
            print(d["udid"])
            sys.exit(0)
sys.exit(1)
' 2>/dev/null) || true

    if [ -z "$booted_udid" ]; then
        print_error "No booted iOS simulator found. Boot one first, e.g.: xcrun simctl boot 'iPhone 16 Pro' && open -a Simulator"
    fi
    print_step "Booted simulator UDID: $booted_udid"

    # `simctl get_app_container booted <bundle>` exits non-zero if the bundle
    # isn't installed. That's a much sharper failure than letting Arbigent
    # trip later when LaunchApp returns "app not found".
    if ! xcrun simctl get_app_container booted "$IOS_BUNDLE_ID" &> /dev/null; then
        print_error "iOS app '$IOS_BUNDLE_ID' is not installed on the booted simulator. Install it first, e.g.: xcrun simctl install booted /path/to/QuickPizzaIos.app"
    fi
    print_step "App $IOS_BUNDLE_ID is installed on simulator"
}

### Report generator setup ####################################################

install_report_deps() {
    if [ ! -f "$REPORT_DIR/package.json" ]; then
        print_error "Missing $REPORT_DIR/package.json — cannot install report dependencies"
    fi
    if (cd "$REPORT_DIR" && node -e "require.resolve('yaml')" 2>/dev/null); then
        return 0
    fi
    print_step "Installing report generator dependencies in $REPORT_DIR..."
    if [ -f "$REPORT_DIR/package-lock.json" ]; then
        (cd "$REPORT_DIR" && npm ci --silent)
    else
        (cd "$REPORT_DIR" && npm install --silent)
    fi
    if ! (cd "$REPORT_DIR" && node -e "require.resolve('yaml')" 2>/dev/null); then
        print_error "After install, node still cannot resolve 'yaml' — check $REPORT_DIR/package.json"
    fi
}

generate_report() {
    local result_path="$1"
    print_step "Generating HTML report from $result_path..."
    node "$REPORT_DIR/generate_report.js" --path="$result_path"
}

### Result archiving ##########################################################

next_results_number() {
    local counter=1
    while [ -d "arbigent-result-$counter" ]; do
        ((counter++))
    done
    echo $counter
}

### Test run ##################################################################

render_template() {
    local out="$1"

    if [ ! -f "$RECOVERY_HINTS_FILE" ]; then
        print_error "Missing recovery hints file: $RECOVERY_HINTS_FILE"
    fi
    if [ ! -f "$RENDER_HELPER" ]; then
        print_error "Missing render helper: $RENDER_HELPER"
    fi

    local template_file
    case "$PLATFORM" in
        android) template_file="$TEMPLATE_FILE_ANDROID" ;;
        ios)     template_file="$TEMPLATE_FILE_IOS" ;;
        *)       print_error "render_template: unsupported platform '$PLATFORM'" ;;
    esac
    if [ ! -f "$template_file" ]; then
        print_error "Missing Arbigent template for $PLATFORM: $template_file"
    fi

    node "$RENDER_HELPER" \
        "$template_file" \
        "$RECOVERY_HINTS_FILE" \
        "$ANDROID_PACKAGE" \
        "$IOS_BUNDLE_ID" \
        > "$out"
}

run_tests() {
    local identity
    case "$PLATFORM" in
        android) identity="package=$ANDROID_PACKAGE" ;;
        ios)     identity="bundle=$IOS_BUNDLE_ID" ;;
        *)       identity="" ;;
    esac
    print_step "Running E2E tests for app=$APP platform=$PLATFORM ($identity)..."

    if [ -z "${OPENAI_API_KEY:-}" ]; then
        print_error "OPENAI_API_KEY environment variable is not set"
    fi

    install_report_deps

    mkdir -p "$RESULTS_DIR"
    cd "$RESULTS_DIR"

    local arbigent_os="$PLATFORM"
    local arbigent_args="--os=${arbigent_os} --ai-type=openai --openai-model-name=${ARBIGENT_MODEL} --log-level=debug"
    if [ "$ARBIGENT_LOG_AI_API" = "true" ]; then
        arbigent_args="$arbigent_args --ai-api-logging"
        print_step "AI API request/response logging enabled (ARBIGENT_LOG_AI_API=true)"
    fi

    # Render the per-app project file alongside the run outputs. We keep
    # it (not in /tmp) so it can be inspected after a run — useful for
    # debugging which package id / bundle id Arbigent actually saw.
    local project_file="$RESULTS_DIR/arbigent-project.yaml"
    render_template "$project_file"
    print_step "Rendered Arbigent project: $project_file"

    rm -rf arbigent-result

    # OpenAI vision calls sometimes hit ~80s socket timeouts in CI; retry whole run a few times.
    local arbigent_exit_code=1
    local attempt=1
    local max_attempts=3
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            print_skip "Arbigent exited $arbigent_exit_code; retry $attempt/$max_attempts after pause..."
            rm -rf arbigent-result
            sleep 45
        fi
            set +e
            # shellcheck disable=SC2086
            "$ARBIGENT_DIR/bin/arbigent" run $arbigent_args --project-file="$project_file"
            arbigent_exit_code=$?
            set -e
            [ $arbigent_exit_code -eq 0 ] && break
            attempt=$((attempt + 1))
        done

    if [ -d "arbigent-result" ]; then
        cp "$project_file" arbigent-result/arbigent-project.yaml
        generate_report "$RESULTS_DIR/arbigent-result"
        local next_number
        next_number=$(next_results_number)
        cp -r arbigent-result "arbigent-result-$next_number"
        rm -rf arbigent-result/*
        print_step "Archived results to arbigent-result-$next_number"
        sleep 2
    fi

    print_step "Moving all results to final directory..."
    mkdir -p arbigent-result
    for dir in arbigent-result-*; do
        [ -d "$dir" ] && mv "$dir" arbigent-result/
    done
    cp "$project_file" arbigent-result/arbigent-project.yaml
    sleep 2

    if [ $arbigent_exit_code -ne 0 ]; then
        print_error "Test failed after $max_attempts attempts (last exit code $arbigent_exit_code)"
    fi
}

### Main ######################################################################

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
printf "║   QuickPizza E2E   app=%-14s   platform=%-7s      ║\n" "$APP" "$PLATFORM"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

check_dependencies
download_arbigent

case "$PLATFORM" in
    android)
        check_android_emulator
        check_backend
        cleanup_arbigent_processes
        adb forward --remove-all 2>/dev/null || true
        ;;
    ios)
        check_ios_simulator
        # The iOS simulator shares the host's network namespace, so localhost
        # on the Mac and localhost inside the simulator are the same. No
        # equivalent of `adb reverse` is required.
        check_backend
        cleanup_arbigent_processes
        ;;
esac

run_tests

print_step "All tests completed successfully!"
print_step "Results: $RESULTS_DIR/arbigent-result/"
print_step "Open the HTML report: $RESULTS_DIR/arbigent-result/visual_report.html"
