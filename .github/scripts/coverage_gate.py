#!/usr/bin/env python3
"""Enforce a minimum line-coverage threshold from an lcov file.

Usage: coverage_gate.py coverage/lcov.info THRESHOLD_PERCENT [EXCLUDE_REGEX]

Counts lines (LF/LH records) across all source files, optionally skipping
files whose path matches EXCLUDE_REGEX. Prints a summary and exits 1 when the
percentage is below the threshold. Generated and platform-only code is
excluded in the workflow, not here.
"""
import re
import sys


def main() -> int:
    path = sys.argv[1]
    threshold = float(sys.argv[2])
    exclude = re.compile(sys.argv[3]) if len(sys.argv) > 3 else None

    found = hit = 0
    current = None
    skip = False
    per_file = {}
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("SF:"):
                current = line[3:]
                skip = bool(exclude and exclude.search(current))
            elif line.startswith("LF:") and not skip:
                found += int(line[3:])
                per_file[current] = [int(line[3:]), 0]
            elif line.startswith("LH:") and not skip:
                hit += int(line[3:])
                if current in per_file:
                    per_file[current][1] = int(line[3:])
            elif line == "end_of_record":
                current = None
                skip = False

    if found == 0:
        print("::error::coverage: no instrumented lines found")
        return 1
    pct = 100.0 * hit / found
    print(f"Line coverage: {pct:.2f}% ({hit}/{found} lines), threshold {threshold:.2f}%")
    print(f"::notice title=Line coverage::{pct:.2f}% ({hit}/{found} lines), threshold {threshold:.2f}%")
    worst = sorted(per_file.items(), key=lambda kv: kv[1][1] / max(kv[1][0], 1))[:10]
    for name, (lf, lh) in worst:
        print(f"  {100.0 * lh / max(lf, 1):6.2f}%  {name}")
    if pct + 1e-9 < threshold:
        print(f"::error::Line coverage {pct:.2f}% is below the {threshold:.2f}% gate")
        return 1
    print("Coverage gate passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
