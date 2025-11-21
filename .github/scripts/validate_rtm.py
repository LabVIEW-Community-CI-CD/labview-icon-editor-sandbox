#!/usr/bin/env python3
import csv, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RTM = ROOT / "docs" / "requirements" / "rtm.csv"


def main():
    missing = []
    with open(RTM, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        required = {"id", "title", "priority", "code_path", "test_path", "verification", "owner", "status"}
        if set(reader.fieldnames) != required:
            print(f"RTM header mismatch: {reader.fieldnames} != {sorted(required)}", file=sys.stderr)
            return 2
        for row in reader:
            for key in ["code_path", "test_path"]:
                rel = row[key].strip()
                if rel and not (ROOT / rel).exists():
                    missing.append((row["id"], key, rel))
    if missing:
        print("Missing RTM paths:", file=sys.stderr)
        for item in missing:
            print(f"  {item[0]} -> {item[1]}: {item[2]}", file=sys.stderr)
        return 1
    print("RTM OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
