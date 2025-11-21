#!/usr/bin/env python3
"""Generate a markdown test report tied to the RTM."""

from __future__ import annotations

import csv
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Tuple

ROOT = Path(__file__).resolve().parents[2]
RTM_PATH = ROOT / "docs" / "requirements" / "rtm.csv"
REPORT_PATH = ROOT / "test-report.md"
EXPECTED_HEADER = {
    "id",
    "title",
    "priority",
    "code_path",
    "test_path",
    "verification",
    "owner",
    "status",
}
HIGH_OR_CRITICAL = {"high", "critical"}
MIN_HIGH = 1.0  # 100%
MIN_TOTAL = 0.75  # 75%


@dataclass
class Coverage:
    total: int = 0
    covered: int = 0

    def pct(self) -> float:
        return 1.0 if self.total == 0 else self.covered / self.total


def ensure_header(fieldnames: Iterable[str]) -> None:
    fields = set(fieldnames or [])
    if fields != EXPECTED_HEADER:
        raise SystemExit(
            f"RTM header mismatch: {sorted(fields)} != {sorted(EXPECTED_HEADER)}"
        )


def is_within_repo(path: Path) -> bool:
    try:
        path.relative_to(ROOT)
    except ValueError:
        return False
    return True


def resolve_test_path(raw_path: str) -> Tuple[bool, Path]:
    candidate = raw_path.strip()
    if not candidate:
        return False, Path()
    path = Path(candidate)
    if not path.is_absolute():
        path = ROOT / path
    path = path.resolve()
    if not is_within_repo(path):
        return False, path
    return path.exists(), path


def load_rtm() -> List[dict]:
    with open(RTM_PATH, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        ensure_header(reader.fieldnames)
        return list(reader)


def compute_coverage(rows: List[dict]) -> Tuple[Coverage, Coverage, List[str]]:
    high = Coverage()
    total = Coverage()
    missing: List[str] = []
    for row in rows:
        has_test, path = resolve_test_path(row["test_path"])
        priority = row["priority"].strip().lower()

        total.total += 1
        if has_test:
            total.covered += 1

        if priority in HIGH_OR_CRITICAL:
            high.total += 1
            if has_test:
                high.covered += 1

        if not has_test:
            reason = "missing test path" if not path else f"missing file: {path.relative_to(ROOT)}"
            missing.append(f"{row.get('id','')} [{row['priority']}]: {reason}")
    return high, total, missing


def detect_suites(rows: List[dict]) -> List[str]:
    suites = set()
    for row in rows:
        path_str = row["test_path"].strip()
        if not path_str:
            continue
        parts = Path(path_str).parts
        suite = path_str
        try:
            idx = parts.index("Unit Tests")
            if idx + 1 < len(parts):
                suite = parts[idx + 1]
        except ValueError:
            suite = Path(path_str).parent.name or path_str
        suites.add(suite)
    return sorted(suites)


def write_report(rows: List[dict], high: Coverage, total: Coverage) -> None:
    suites = detect_suites(rows)
    completion = (
        "PASS"
        if high.pct() >= MIN_HIGH and total.pct() >= MIN_TOTAL
        else "FAIL"
    )

    lines: List[str] = []
    lines.append("# Test Report")
    lines.append("")
    lines.append("## Objectives")
    lines.append("- Validate regression coverage against RTM entries (functional and non-functional).")
    lines.append("- Confirm LabVIEW unit test suites exercise mapped requirements.")
    lines.append("- Record completion against RTM thresholds.")
    lines.append("")
    lines.append("## Completion Status")
    lines.append(
        f"- Completion: **{completion}** "
        f"(High/Critical: {high.covered}/{high.total} = {high.pct():.0%}; "
        f"Overall: {total.covered}/{total.total} = {total.pct():.0%}; "
        f"required >= {MIN_HIGH:.0%}/{MIN_TOTAL:.0%})"
    )
    lines.append("- Unit test execution: runs in self-hosted jobs `test-2021-x64` and `test-2021-x86` (see CI pipeline); this report captures RTM mapping and coverage prerequisites.")
    if suites:
        lines.append(f"- LabVIEW unit test suites referenced: {', '.join(suites)}")
    lines.append("")
    lines.append("## RTM to Test Mapping")
    lines.append("")
    lines.append("| Requirement | Priority | Objective | Test Path |")
    lines.append("| --- | --- | --- | --- |")
    for row in rows:
        lines.append(
            f"| {row['id']} | {row['priority']} | {row['title']} | `{row['test_path']}` |"
        )
    lines.append("")
    lines.append("## Evidence Sources")
    lines.append("- RTM source: `docs/requirements/rtm.csv`")
    lines.append("- Coverage enforcement: `.github/scripts/check_rtm_coverage.py`")
    lines.append("- Unit test runner: `.github/actions/run-unit-tests/RunUnitTests.ps1`")
    lines.append("")

    REPORT_PATH.write_text("\n".join(lines))


def main() -> int:
    try:
        rows = load_rtm()
    except Exception as exc:
        print(f"Failed to load RTM: {exc}", file=sys.stderr)
        return 2

    high, total, missing = compute_coverage(rows)
    if missing:
        print("Missing coverage entries:")
        for item in missing:
            print(f"- {item}", file=sys.stderr)
        return 1

    write_report(rows, high, total)

    if high.pct() < MIN_HIGH or total.pct() < MIN_TOTAL:
        print("Coverage thresholds not met; report generated but failing pipeline.", file=sys.stderr)
        return 1

    print(f"Wrote {REPORT_PATH} with coverage summary.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
