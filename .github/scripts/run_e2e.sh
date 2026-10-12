#!/usr/bin/env bash
# Runs the on-device integration test on the already-booted emulator.
#
# Result contract (read by the workflow):
#  * e2e.txt  — everything this script and flutter test printed.
#  * e2e.rc   — the exit code of the test run. It is written on every exit path,
#               including early failures, so a missing file always means the
#               script itself never ran to completion.
#  * e2e-proc.log — process/memory samples every 15 s while the test runs.
#
# The test runs in its own session (setsid) so that a signal to this script does
# not silently drop its exit code; the script waits for e2e.rc, bounded below.
set -uo pipefail

# Create the result file first: a failure before any output must still leave
# evidence behind (the workflow previously saw neither e2e.txt nor e2e.rc).
: > e2e.txt
rm -f e2e.rc
finish() {
  local rc=$?
  if [ ! -f e2e.rc ]; then echo "$rc" > e2e.rc; fi
}
trap finish EXIT

log() { echo "$*" | tee -a e2e.txt; }

log "run_e2e: ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-<unset>} ANDROID_HOME=${ANDROID_HOME:-<unset>}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-/usr/local/lib/android/sdk}}"
ADB="$SDK/platform-tools/adb"
if [ ! -x "$ADB" ]; then
  log "adb not found at $ADB"
  exit 1
fi

DEVICE="$("$ADB" devices 2>>e2e.txt | awk 'NR>1 && $2=="device" {print $1; exit}')"
log "device=${DEVICE:-<none>}"
if [ -z "$DEVICE" ]; then
  log "No booted Android device found"
  exit 1
fi

( while sleep 15; do
    echo "== $(date +%T) $(free -m | sed -n 2p)"
    ps -eo pid,ppid,pcpu,rss,etime,args --sort=-rss | head -6 | cut -c1-160
  done ) > e2e-proc.log 2>&1 &
SAMPLER=$!

setsid bash -c 'flutter test integration_test/app_test.dart -d "$1" > e2e.txt 2>&1 < /dev/null; echo $? > e2e.rc' _ "$DEVICE" &

# Wait up to 30 minutes for the test session to write its exit code.
for _ in $(seq 1 180); do
  [ -f e2e.rc ] && break
  sleep 10
done
kill "$SAMPLER" 2>/dev/null || true

rc="$(cat e2e.rc 2>/dev/null || echo missing)"
echo "flutter test exit code: $rc" | tee -a e2e.txt
python3 .github/scripts/annotate_output.py e2e.txt 60
if [ "$rc" != "0" ]; then echo "E2E failed (exit code $rc)"; exit 1; fi
if grep -q "Some tests failed\|tests passed, [1-9][0-9]* failed\|BUILD FAILED\|Failing tests" e2e.txt; then
  echo "E2E output reports failure"; exit 1
fi
# Each test prints one E2E_OK marker when its last expectation has run.
markers="$(grep -c "E2E_OK:" e2e.txt || true)"
echo "E2E_OK markers: $markers (expected 2)"
if [ "$markers" -ne 2 ]; then echo "E2E markers missing"; exit 1; fi
echo "E2E passed"
