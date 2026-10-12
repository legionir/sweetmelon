#!/usr/bin/env bash
# Publish the exact `dart format` diffs for every unformatted file as one or
# more pull-request comments, so the formatting can be fixed without access to
# the raw job log. Comment bodies are unified diffs that `patch -p1` can apply.
# Large diff sets are split across multiple comments (GitHub caps comments at
# 65536 characters).
#
# Usage: format_diagnostic.sh [targets...]
set -uo pipefail

TARGETS="${*:-lib test integration_test}"
BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
REPO="${GITHUB_REPOSITORY:-}"

PR="$(gh pr list --repo "$REPO" --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)"
if [ -z "$PR" ]; then
  echo "format_diagnostic: no PR found for branch '$BRANCH'; skipping comment"
  exit 0
fi

TMPDIR_FMT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_FMT"' EXIT

dart format --output=none --set-exit-if-changed $TARGETS > "$TMPDIR_FMT/format.txt" 2>&1 || true

CHANGED="$(grep '^Changed ' "$TMPDIR_FMT/format.txt" | sed 's/^Changed //' | head -500)"
if [ -z "$CHANGED" ]; then
  echo "format_diagnostic: everything is formatted"
  exit 0
fi

# Accumulate per-file diffs, flushing a PR comment whenever the body grows
# past ~48k characters.
BODY="$TMPDIR_FMT/body.md"
PART=1
TOTAL=0
flush() {
  [ -s "$BODY" ] || return 0
  python3 - "$BODY" <<'PY'
import sys
p = sys.argv[1]
data = open(p, encoding="utf-8", errors="replace").read()
if len(data) > 60000:
    data = data[:60000] + "\n\n… (truncated)"
open(p, "w", encoding="utf-8").write(data)
PY
  gh pr comment "$PR" --repo "$REPO" --body-file "$BODY" > /dev/null 2>&1 \
    || echo "format_diagnostic: failed to post comment part $PART on PR #$PR"
  echo "format_diagnostic: posted part $PART ($TOTAL files so far)"
  : > "$BODY"
  PART=$((PART + 1))
  TOTAL=0
}

{
  echo "## CI diagnostic: dart format diffs (part $PART)"
  echo ""
  echo "- Run: ${GITHUB_SERVER_URL:-https://github.com}/$REPO/actions/runs/${GITHUB_RUN_ID:-unknown}"
  echo "- Commit: ${GITHUB_SHA:-unknown}"
  echo ""
  echo "Unformatted files (apply with \`patch -p1\`):"
  echo ""
  echo '```diff'
} > "$BODY"

while IFS= read -r f; do
  [ -f "$f" ] || continue
  cp "$f" "$TMPDIR_FMT/orig"
  dart format "$f" > /dev/null 2>&1 || true
  diff -u --label "a/$f" --label "b/$f" "$TMPDIR_FMT/orig" "$f" > "$TMPDIR_FMT/one.patch" || true
  cp "$TMPDIR_FMT/orig" "$f"
  SIZE=$(wc -c < "$TMPDIR_FMT/one.patch")
  if [ "$SIZE" -gt 0 ]; then
    if [ "$(wc -c < "$BODY")" -gt 48000 ]; then
      echo '```' >> "$BODY"
      flush
      {
        echo "## CI diagnostic: dart format diffs (part $PART)"
        echo ""
        echo "- Run: ${GITHUB_SERVER_URL:-https://github.com}/$REPO/actions/runs/${GITHUB_RUN_ID:-unknown}"
        echo "- Commit: ${GITHUB_SHA:-unknown}"
        echo ""
        echo "Unformatted files (apply with \`patch -p1\`):"
        echo ""
        echo '```diff'
      } > "$BODY"
    fi
    cat "$TMPDIR_FMT/one.patch" >> "$BODY"
    TOTAL=$((TOTAL + 1))
  fi
done <<< "$CHANGED"

echo '```' >> "$BODY"
flush
echo "format_diagnostic: $TOTAL unformatted files, $((PART - 1)) comment(s)"
exit 0
