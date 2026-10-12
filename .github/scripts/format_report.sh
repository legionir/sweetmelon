#!/usr/bin/env bash
# Strict dart format check. For every file that is not formatted, publishes the
# exact formatter diff as a check run (readable through the checks API), then
# fails the job. The workspace copy of each file is restored after the diff.
set -uo pipefail
TARGETS="lib test integration_test"
rc=0
dart format --output=none --set-exit-if-changed $TARGETS > format.txt 2>&1 || rc=$?
tail -3 format.txt
if [ "$rc" -eq 0 ]; then
  echo "dart format: clean"
  exit 0
fi
python3 .github/scripts/annotate_output.py format.txt 80

mkdir -p format-report
grep '^Changed ' format.txt | sed 's/^Changed //' | while read -r f; do
  safe="$(echo "$f" | tr '/' '_')"
  cp "$f" "format-report/$safe.orig"
  dart format "$f" > /dev/null 2>&1
  diff -u "format-report/$safe.orig" "$f" > "format-report/$safe.diff"
  cp "format-report/$safe.orig" "$f"
  head -c 60000 "format-report/$safe.diff" > "format-report/$safe.trim"
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    gh api "repos/$GITHUB_REPOSITORY/check-runs" -X POST \
      -f name="dart format: $f" -f head_sha="$GITHUB_SHA" -f status=completed \
      -f conclusion=neutral -f "output[title]=dart format diff" \
      -f "output[summary]=Formatter output for $f" \
      -F "output[text]=@format-report/$safe.trim" > /dev/null \
      || echo "could not publish diff for $f"
  fi
done
exit "$rc"
