#!/bin/bash
set -e

# Trap handler for cleanup on script interruption
cleanup_on_exit() {
    print_step "Script interrupted, cleaning up..."

    # Kill any Java processes that might be from Arbigent runs
    local java_pids=$(ps aux | grep -i java | grep -v grep | awk '{print $2}')
    if [ -n "$java_pids" ]; then
        for pid in $java_pids; do
            if ps -p "$pid" -o command= | grep -q -i "arbigent\|maestro\|dadb" 2>/dev/null; then
                echo "Killing Arbigent-related process: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    # Kill any Arbigent processes
    local arbigent_pids=$(ps aux | grep -i arbigent | grep -v grep | awk '{print $2}')
    if [ -n "$arbigent_pids" ]; then
        echo "Killing Arbigent processes: $arbigent_pids"
        kill -9 $arbigent_pids 2>/dev/null || true
    fi

    # Clean up ADB port forwards
    adb forward --remove-all 2>/dev/null || true

    exit 1
}

# Set up trap for common interrupt signals
trap cleanup_on_exit INT TERM QUIT

### Test Setup #################################################################
### Change config in here #####################################################

# Configuration
ARBIGENT_VERSION="0.67.0"
ARBIGENT_DOWNLOAD_URL="https://github.com/takahirom/arbigent/releases/download/${ARBIGENT_VERSION}/arbigent-${ARBIGENT_VERSION}.zip"
ARBIGENT_DIR="/tmp/arbigent-${ARBIGENT_VERSION}"

### Actual script starts below here ############################################
### Probably don't change anything below here ##################################

# Get script location and project root (React Native app root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RN_ROOT="$(cd "$SCRIPT_DIR/../.." &> /dev/null && pwd)"

# Shared Arbigent template under Mobiles/e2e/ (ANDROID_PACKAGE substituted per app)
MOBILES_ROOT="$(cd "$SCRIPT_DIR/../../.." &> /dev/null && pwd)"
ARBIGENT_PROJECT_TEMPLATE="$MOBILES_ROOT/e2e/arbigent-e2e_basic_pizza_flow.yaml.template"
ANDROID_PACKAGE="${ANDROID_PACKAGE:-com.quickpizza}"
ARBIGENT_PROJECTS=(
    "Mobiles/e2e/arbigent-e2e_basic_pizza_flow.yaml"
)

# Environment detection
is_github_actions() {
    [ -n "$GITHUB_ACTIONS" ]
}

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
print_step() {
    echo -e "${GREEN}===> $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}"
    exit 1
}

print_skip() {
    echo -e "${YELLOW}SKIP: $1${NC}"
}

get_next_results_number() {
    local counter=1
    while [ -d "arbigent-result-$counter" ]; do
        ((counter++))
    done
    echo $counter
}

check_dependencies() {
    print_step "Checking dependencies..."

    # Check for required commands
    for cmd in adb unzip; do
        if ! command -v $cmd &> /dev/null; then
            print_error "$cmd is required but not installed"
        fi
    done

    # Check for wget or curl
    if command -v wget &> /dev/null; then
        DOWNLOAD_CMD="wget"
    elif command -v curl &> /dev/null; then
        DOWNLOAD_CMD="curl"
    else
        print_error "Either wget or curl is required but neither is installed"
    fi
}

download_arbigent() {
    if [ ! -d "$ARBIGENT_DIR" ]; then
        print_step "Downloading Arbigent v${ARBIGENT_VERSION}..."
        local original_dir=$(pwd)
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
    else
        print_step "Arbigent already downloaded at $ARBIGENT_DIR"
    fi
}

check_backend() {
    print_step "Checking QuickPizza backend connectivity..."

    local backend_url="${QUICKPIZZA_BACKEND_URL:-http://localhost:3333}"
    local backend_ready="${backend_url}/ready"

    if curl -fsS --connect-timeout 5 "$backend_ready" > /dev/null 2>&1; then
        print_step "Backend is reachable at $backend_url"
    else
        print_error "QuickPizza backend is not reachable at $backend_url. Ensure the backend is running and adb reverse is set: adb reverse tcp:3333 tcp:3333"
    fi
}

check_emulator() {
    print_step "Checking Android emulator..."

    # Check if any emulator is running
    if ! adb devices | grep -q "emulator"; then
        print_error "No Android emulator found. Please start an emulator first."
    fi

    # Wait for emulator to be fully booted
    echo "Waiting for emulator to be fully booted..."
    adb wait-for-device shell 'while [ -z "$(getprop sys.boot_completed)" ]; do sleep 1; done'

    # List available devices for debugging
    print_step "Available devices:"
    adb devices -l
}

# Report needs Node + generate_report.js + npm package `yaml` from Mobiles/react-native/package.json devDependencies.
html_report_possible() {
    command -v node &> /dev/null && [ -f "$SCRIPT_DIR/generate_report.js" ]
}

yaml_report_module_ready() {
    (cd "$RN_ROOT" && node -e "require.resolve('yaml')" 2>/dev/null)
}

check_report_generator() {
    if ! html_report_possible; then
        if ! command -v node &> /dev/null; then
            print_skip "Node.js not found; HTML report generation will be skipped (raw results will still be saved)"
        else
            print_skip "Report generator not found at $SCRIPT_DIR/generate_report.js; HTML report generation will be skipped"
        fi
        return 1
    fi
    return 0
}

# Install RN workspace deps before E2E so HTML report never depends on a prior manual yarn install (e.g. CI).
# Exits the script on failure instead of skipping report generation.
install_rn_deps_for_e2e_report() {
    if yaml_report_module_ready; then
        return 0
    fi
    if [ ! -f "$RN_ROOT/package.json" ]; then
        print_error "Missing $RN_ROOT/package.json; cannot install report dependencies"
    fi
    print_step "Installing Mobiles/react-native dependencies (required for E2E HTML report: yaml)..."
    cd "$RN_ROOT"
    if command -v yarn &> /dev/null; then
        yarn install --frozen-lockfile || yarn install
    elif command -v npm &> /dev/null; then
        # RN ships yarn.lock only; npm install from package.json is enough for report deps (e.g. yaml).
        npm install
    else
        print_error "Neither yarn nor npm found. Install Node.js (includes npm) or Yarn, then re-run E2E."
    fi
    if ! yaml_report_module_ready; then
        print_error "After install, Node still cannot resolve 'yaml'. Check devDependencies in $RN_ROOT/package.json"
    fi
}

cleanup_processes() {
    print_step "Cleaning up any lingering processes..."

    # Kill any Java processes that might be from previous Arbigent runs
    local java_pids=$(ps aux | grep -i java | grep -v grep | awk '{print $2}')
    if [ -n "$java_pids" ]; then
        for pid in $java_pids; do
            # Check if this is likely an Arbigent process
            if ps -p "$pid" -o command= | grep -q -i "arbigent\|maestro\|dadb" 2>/dev/null; then
                print_step "Killing Arbigent-related process: $pid"
                kill -9 "$pid" 2>/dev/null || true
            fi
        done
    fi

    # Kill any processes specifically named arbigent
    local arbigent_pids=$(ps aux | grep -i arbigent | grep -v grep | awk '{print $2}')
    if [ -n "$arbigent_pids" ]; then
        print_step "Killing Arbigent processes: $arbigent_pids"
        kill -9 $arbigent_pids 2>/dev/null || true
    fi

    # Clean up any leftover port forwards
    print_step "Cleaning up ADB port forwards..."
    adb forward --remove-all 2>/dev/null || true

    # Wait a moment for cleanup to complete
    sleep 2

    print_step "Process cleanup completed"
}

run_tests() {
    print_step "Running E2E tests..."

    if [ -z "$OPENAI_API_KEY" ]; then
        print_error "OPENAI_API_KEY environment variable is not set. Export it before running this script."
    fi

    # Change to React Native root directory for test execution
    cd "$RN_ROOT"

    if [ ! -f "$ARBIGENT_PROJECT_TEMPLATE" ]; then
        print_error "Missing Arbigent template: $ARBIGENT_PROJECT_TEMPLATE"
    fi

    if html_report_possible; then
        install_rn_deps_for_e2e_report
    fi

    # Use same model as Flutter E2E (gpt-5.2) for consistency
    local ARBIGENT_ARGS="--os=android --ai-type=openai --openai-model-name=gpt-5.2 --log-level=debug"
    local test_failed=false
    local failed_tests=()

    for test_file in "${ARBIGENT_PROJECTS[@]}"; do
        print_step "Running test: ${test_file} (package ${ANDROID_PACKAGE})..."

        local tmp_project
        tmp_project="$(mktemp "${TMPDIR:-/tmp}/arbigent-rn.XXXXXX")"
        sed "s/__ANDROID_PACKAGE__/${ANDROID_PACKAGE}/g" "$ARBIGENT_PROJECT_TEMPLATE" > "$tmp_project"

        # Clean up any leftover results
        rm -rf arbigent-result

        # OpenAI vision calls sometimes hit ~80s socket timeouts in CI; retry whole run a few times.
        local arbigent_exit_code=1
        local attempt=1
        local max_attempts=3
        while [ $attempt -le $max_attempts ]; do
            if [ $attempt -gt 1 ]; then
                print_step "Arbigent exited $arbigent_exit_code; retry $attempt/$max_attempts after pause..."
                rm -rf arbigent-result
                sleep 45
            fi
            set +e
            "$ARBIGENT_DIR/bin/arbigent" run $ARBIGENT_ARGS --project-file="$tmp_project"
            arbigent_exit_code=$?
            set -e
            if [ $arbigent_exit_code -eq 0 ]; then
                break
            fi
            attempt=$((attempt + 1))
        done

        rm -f "$tmp_project"

        # Process results if they exist
        if [ -d "arbigent-result" ]; then
            if check_report_generator; then
                print_step "Generating HTML report for ${test_file}..."
                local result_path="$RN_ROOT/arbigent-result"
                node "$SCRIPT_DIR/generate_report.js" --path="$result_path"
            fi

            local next_number=$(get_next_results_number)
            # Copy results to numbered directory
            cp -r arbigent-result "arbigent-result-$next_number"
            rm -rf arbigent-result/*
            print_step "Copied results to arbigent-result-$next_number"

            # Add a short delay
            sleep 2
        fi

        if [ $arbigent_exit_code -ne 0 ]; then
            echo -e "${RED}Test failed: ${test_file}${NC}"
            test_failed=true
            failed_tests+=("$test_file")
            echo -e "${YELLOW}Stopping test execution due to test failure${NC}"
            break
        fi
    done

    # Always move all results back into arbigent-result directory
    print_step "Moving all results to final directory..."
    mkdir -p arbigent-result
    for dir in arbigent-result-*; do
        if [ -d "$dir" ]; then
            mv "$dir" arbigent-result/
        fi
    done

    # Wait to ensure all files are properly moved
    sleep 2

    # If any test failed, show which ones and exit with error
    if [ "$test_failed" = true ]; then
        echo -e "${RED}The following test failed:${NC}"
        echo -e "${RED}- ${failed_tests[0]}${NC}"
        print_error "Test failed"
    fi
}

show_help() {
    echo "QuickPizza RN E2E Test Runner"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  1. Android emulator running with the app installed"
    echo "  2. OPENAI_API_KEY environment variable set"
    echo ""
    echo "Example:"
    echo "  export OPENAI_API_KEY='your-api-key'"
    echo "  $0"
    echo ""
}

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done

    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║        QuickPizza RN E2E Test Runner                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    check_dependencies
    download_arbigent
    check_emulator
    check_backend
    cleanup_processes
    run_tests

    print_step "All tests completed successfully!"
    print_step "Test results available in: $RN_ROOT/arbigent-result/"
}

# Run main function
main "$@"
