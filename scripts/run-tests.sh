#!/bin/bash
shopt -s globstar

while getopts "u:t:" flag; do
  case $flag in
  u) BASE_URL="$OPTARG" ;;
  t) TESTS="$OPTARG" ;;
  esac
done

BASE_URL="${BASE_URL:=http://localhost:3333}"
TESTS="${TESTS:=**/k6/foundations/*.js}"
LOGS=logs.txt

export K6_BROWSER_HEADLESS=true 
export K6_BROWSER_ARGS='no-sandbox' 
if [ "$ACT" = "true" ]; then
	export K6_BROWSER_EXECUTABLE_PATH=/usr/bin/google-chrome
fi

for test in $TESTS; do
	# Disable thresholds because some threshold examples fail
    rm -f $LOGS
	k6 run --no-thresholds -e BASE_URL=$BASE_URL --log-output=file=$LOGS --log-format=json -w --no-summary "$test"

	exit_code=$?
	if [ $exit_code -ne 0 ]; then
		exit $exit_code
	fi

    jq .level --raw-output < $LOGS | grep -v error > /dev/null

	exit_code=$?
	if [ $exit_code -ne 0 ]; then
        cat $LOGS
		exit $exit_code
	fi
done
