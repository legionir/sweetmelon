#!/usr/bin/env python3
"""Turn tool output into GitHub annotations so failures are visible in the
checks API, not only in the raw job log.

Usage: annotate_output.py FILE [MAX_LINES]
Prints `::error::` workflow commands for diagnostic lines. Never fails the job;
the calling step decides the exit code.
"""
import re
import sys

ANALYZER = re.compile(
    r"^\s*(error|warning|info)\s+•\s+(?P<msg>.*?)\s+•\s+(?P<path>[^:]+):(?P<line>\d+):\d+\s+•")
KEYWORDS = re.compile(
    r"(^e: |What went wrong|Could not|FAILURE|BUILD FAILED|Exception|Error:|"
    r"Expected:|Actual:|Which:|\[E\]|Some tests failed|FAILED|Unhandled|"
    r"Null check|No such file|not found|\bERROR\b)")


def escape(text: str) -> str:
    return text.replace("%", "%25").replace("\r", "").replace("\n", " ")


def main() -> int:
    path = sys.argv[1]
    limit = int(sys.argv[2]) if len(sys.argv) > 2 else 60
    count = 0
    with open(path, encoding="utf-8", errors="replace") as fh:
        # Split on CR too: progress bars rewrite one physical line many times.
        lines = [part for raw in fh for part in re.split(r"[\r\n]+", raw.rstrip("\n"))]
    print(f"::notice::annotate_output scanned {len(lines)} lines from {path}")
    follow = 0  # lines to keep after a "What went wrong" heading
    for line in lines:
        if count >= limit:
            break
        if follow > 0 and line.strip():
            print(f"::error::{escape(line.strip())[:500]}")
            count += 1
            follow -= 1
            continue
        m = ANALYZER.match(line)
        if m:
            level = "error" if m.group(1) == "error" else "warning"
            print(f"::{level} file={m.group('path')},line={m.group('line')}::"
                  f"{escape(m.group('msg'))}")
            count += 1
        elif KEYWORDS.search(line):
            print(f"::error::{escape(line.strip())[:500]}")
            count += 1
            if "What went wrong" in line:
                follow = 6
    if count == 0:
        # Nothing recognised: surface the tail so the failure is still visible.
        for line in [ln for ln in lines if ln.strip()][-40:]:
            print(f"::error::TAIL {escape(line.strip())[:500]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
