#!/bin/bash
shopt -s globstar

while getopts "u:t:" flag; do
  case $flag in
  u) BASE_URL="$OPTARG" ;;
  t) TESTS="$OPTARG" ;;
  *) echo "unknown flag"; exit 1
  esac
done

BASE_URL="${BASE_URL:=http://localhost:3333}"
K6_PATH="${K6_PATH:=k6}"
TESTS="${TESTS:=**/k6/foundations/*.js}"
LOGS=logs.txt

export K6_BROWSER_HEADLESS=true
# Chrome 146+: crashpad reads cpufreq sysfs that GitHub runners omit; disable the
# triggering feature. Comma-separated K6_BROWSER_ARGS must not include commas
# inside values, so we pass only this feature (replaces k6's default disable-features).
# https://github.com/puppeteer/puppeteer/issues/14742
export K6_BROWSER_ARGS='no-sandbox,disable-dev-shm-usage,disable-features=PartitionAllocSchedulerLoopQuarantineTaskControlledPurge'
# Bundled Chromium can fail mid-run when many IterStart launches happen in parallel
# (e.g. hybrid browser + HTTP scenarios). Prefer system Chrome on Linux CI; see
# https://github.com/grafana/xk6-browser/blob/main/.github/workflows/e2e.yml
if [ "$ACT" = "true" ] || { [ -n "${CI:-}" ] && [ "$(uname -s)" = "Linux" ]; }; then
	export K6_BROWSER_EXECUTABLE_PATH="${K6_BROWSER_EXECUTABLE_PATH:-/usr/bin/google-chrome-stable}"
	# Headless Linux runners: avoid Chromium D-Bus launch failures.
	export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-/dev/null}"
fi

for test in $TESTS; do
	# Disable thresholds because some threshold examples fail
    echo "Running: $test"
    rm -f $LOGS
	$K6_PATH run --no-thresholds -e BASE_URL="$BASE_URL" --log-output=file=$LOGS --log-format=json -w --no-summary "$test"
    k6_exit_code=$?

    # Only check error logs if logs file is not empty.
    if [ -s $LOGS ]; then
        jq .level --raw-output < $LOGS | grep -v error > /dev/null

	    exit_code=$?
	    if [ $exit_code -ne 0 ]; then
            cat $LOGS
		    exit $exit_code
	    fi
    fi

	if [ $k6_exit_code -ne 0 ]; then
		exit $k6_exit_code
	fi
done
