#!/usr/bin/env python3
"""Summarize recent repository development telemetry from git history.

This script uses local git history only; it does not require GitHub API access.
It is advisory and intended to reveal churn/hotspot patterns that may justify a
bounded leverage pass.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from collections import Counter
from pathlib import Path

from _console import use_utf8_output

ROOT = Path(__file__).resolve().parents[1]


def run_git(*args: str) -> str:
    result = subprocess.run(["git", *args], cwd=ROOT, text=True, capture_output=True, check=False)
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result.stdout


def collect(days: int) -> dict:
    log = run_git("log", f"--since={days} days ago", "--numstat", "--format=COMMIT\t%H\t%ad\t%s", "--date=short", "--", "games/living-kingdoms", "scripts", "docs/roadmap")
    commits = 0
    insertions = 0
    deletions = 0
    touches: Counter[str] = Counter()
    churn: Counter[str] = Counter()
    subjects: list[str] = []
    for line in log.splitlines():
        if line.startswith("COMMIT\t"):
            commits += 1
            parts = line.split("\t", 3)
            if len(parts) == 4:
                subjects.append(parts[3])
            continue
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        added, removed, path = parts
        if added == "-" or removed == "-":
            continue
        a, d = int(added), int(removed)
        insertions += a
        deletions += d
        touches[path] += 1
        churn[path] += a + d
    return {
        "window_days": days,
        "commits": commits,
        "insertions": insertions,
        "deletions": deletions,
        "top_touched_files": touches.most_common(15),
        "top_churn_files": churn.most_common(15),
        "recent_subjects": subjects[:20],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--days", type=int, default=14)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    try:
        payload = collect(args.days)
    except RuntimeError as exc:
        print(f"dev metrics unavailable: {exc}")
        return 1
    if args.json:
        print(json.dumps(payload, indent=2))
        return 0
    print(f"Development telemetry — last {payload['window_days']} days")
    print(f"commits={payload['commits']} churn=+{payload['insertions']}/-{payload['deletions']}")
    print("\nMost frequently touched:")
    for path, count in payload["top_touched_files"][:10]:
        print(f"  {count:>3}  {path}")
    print("\nHighest churn:")
    for path, count in payload["top_churn_files"][:10]:
        print(f"  {count:>5}  {path}")
    print("\nInterpretation: repeated high touch + high churn is a candidate for ownership/tooling/regression review, not automatic refactoring.")
    return 0


if __name__ == "__main__":
    use_utf8_output()
    raise SystemExit(main())
