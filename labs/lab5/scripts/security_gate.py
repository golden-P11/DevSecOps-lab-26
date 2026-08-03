#!/usr/bin/env python3
"""Security gate: ERROR findings must be 0; WARNING findings must be <= 5."""

from __future__ import annotations

import json
import sys
from pathlib import Path

MAX_WARNINGS = 5


def count_semgrep(report_path: Path) -> tuple[int, int]:
    with report_path.open(encoding="utf-8") as handle:
        data = json.load(handle)

    errors = warnings = 0
    for result in data.get("results", []):
        severity = (result.get("extra") or {}).get("severity", "").upper()
        if severity == "ERROR":
            errors += 1
        elif severity == "WARNING":
            warnings += 1
    return errors, warnings


def count_zap(report_path: Path) -> tuple[int, int]:
    """Map ZAP High -> ERROR, Medium -> WARNING."""
    with report_path.open(encoding="utf-8") as handle:
        data = json.load(handle)

    errors = warnings = 0
    for site in data.get("site", []):
        for alert in site.get("alerts", []):
            risk = str(alert.get("riskcode", "0"))
            if risk == "3":
                errors += 1
            elif risk == "2":
                warnings += 1
    return errors, warnings


def evaluate(label: str, errors: int, warnings: int) -> bool:
    print(f"{label}:")
    print(f"  ERROR findings:   {errors} (required: 0)")
    print(f"  WARNING findings: {warnings} (required: <= {MAX_WARNINGS})")

    if errors > 0:
        print("  FAIL: ERROR findings must be 0.", file=sys.stderr)
        return False
    if warnings > MAX_WARNINGS:
        print(
            f"  FAIL: WARNING findings exceed limit of {MAX_WARNINGS}.",
            file=sys.stderr,
        )
        return False

    print("  PASS")
    return True


def main() -> int:
    if len(sys.argv) < 3:
        print(
            f"Usage: {sys.argv[0]} <semgrep|zap> <report.json> [report2.json ...]",
            file=sys.stderr,
        )
        return 2

    tool = sys.argv[1].lower()
    report_paths = [Path(p) for p in sys.argv[2:]]

    if tool not in {"semgrep", "zap"}:
        print(f"Unknown tool: {tool}", file=sys.stderr)
        return 2

    counter = count_semgrep if tool == "semgrep" else count_zap
    passed = True

    for report_path in report_paths:
        if not report_path.is_file():
            print(f"Report not found: {report_path}", file=sys.stderr)
            return 2

        errors, warnings = counter(report_path)
        label = f"Security gate ({tool}) — {report_path.name}"
        if not evaluate(label, errors, warnings):
            passed = False

    if not passed:
        print("\nSecurity gate FAILED.", file=sys.stderr)
        return 1

    print("\nSecurity gate PASSED.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
