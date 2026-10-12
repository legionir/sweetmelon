#!/usr/bin/env bash
# Post a CI diagnostic excerpt as a pull-request comment so failures are
# readable through the API without downloading raw job logs.
#
# Usage: pr_diagnostic.sh "TITLE" file1 [file2 ...]
# Never fails the job. Requires the pull-requests:write permission and
# GH_TOKEN/GITHUB_TOKEN in the environment.
set -uo pipefail

TITLE="${1:-CI diagnostic}"
shift || true

BRANCH="${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}"
REPO="${GITHUB_REPOSITORY:-}"

PR="$(gh pr list --repo "$REPO" --head "$BRANCH" --json number --jq '.[0].number' 2>/dev/null || true)"
if [ -z "$PR" ]; then
  echo "pr_diagnostic: no PR found for branch '$BRANCH'; skipping comment"
  exit 0
fi

BODY_FILE="$(mktemp)"
{
  echo "## CI diagnostic: $TITLE"
  echo ""
  echo "- Run: ${GITHUB_SERVER_URL:-https://github.com}/$REPO/actions/runs/${GITHUB_RUN_ID:-unknown}"
  echo "- Commit: ${GITHUB_SHA:-unknown}"
  echo "- Job: ${GITHUB_JOB:-unknown}"
  echo ""
  for f in "$@"; do
    if [ -f "$f" ]; then
      echo "### \`$f\` (tail)"
      echo ""
      echo '```'
      tail -c 25000 "$f"
      echo '```'
      echo ""
    fi
  done
} > "$BODY_FILE"

# GitHub caps comments at 65536 characters.
python3 - "$BODY_FILE" <<'PY'
import sys
p = sys.argv[1]
data = open(p, encoding="utf-8", errors="replace").read()
if len(data) > 60000:
    data = data[:60000] + "\n\n… (truncated)"
open(p, "w", encoding="utf-8").write(data)
PY

gh pr comment "$PR" --repo "$REPO" --body-file "$BODY_FILE" > /dev/null 2>&1 \
  || echo "pr_diagnostic: failed to post comment on PR #$PR"
exit 0
