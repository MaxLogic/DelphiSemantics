#!/usr/bin/env python3
"""Parse MaxProfiler summary `.maxprof` captures.

The report builder is the preferred path. This helper exists for Win32 summary
captures where the report builder produces empty tables although summary records
and the string table are valid.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any


RECORD_SIZE = 68
HEADER_SIZE = 16
RECORD_FORMAT = "<Idddddddd"


def find_single(path: Path, pattern: str) -> Path:
    matches = sorted(path.glob(pattern))
    if len(matches) != 1:
        raise SystemExit(f"Expected exactly one {pattern} in {path}, found {len(matches)}")
    return matches[0]


def load_strings(path: Path) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            entries.append({"idx": int(parts[0]), "unit": parts[1], "method": parts[2]})
    return entries


def parse_summary(profile_path: Path, strings_path: Path, meta_path: Path) -> dict[str, Any]:
    meta = json.loads(meta_path.read_text(encoding="utf-8-sig"))
    entries = load_strings(strings_path)
    data = profile_path.read_bytes()[HEADER_SIZE:]
    rows: list[dict[str, Any]] = []

    for i, entry in enumerate(entries[: len(data) // RECORD_SIZE]):
        start = i * RECORD_SIZE
        record = data[start : start + RECORD_SIZE]
        call_count, gross, net, avg_gross, avg_net, max_net, p95, child, self_pct = struct.unpack(
            RECORD_FORMAT, record
        )
        if call_count:
            rows.append(
                {
                    **entry,
                    "callCount": call_count,
                    "totalGrossMs": gross,
                    "totalNetMs": net,
                    "avgGrossMs": avg_gross,
                    "avgNetMs": avg_net,
                    "maxNetMs": max_net,
                    "p95NetMs": p95,
                    "childMs": child,
                    "selfPct": self_pct,
                }
            )

    units: dict[str, dict[str, Any]] = {}
    for row in rows:
        unit = units.setdefault(row["unit"], {"unit": row["unit"], "calls": 0, "grossMs": 0.0, "netMs": 0.0})
        unit["calls"] += row["callCount"]
        unit["grossMs"] += row["totalGrossMs"]
        unit["netMs"] += row["totalNetMs"]

    return {
        "meta": meta,
        "topNet": sorted(rows, key=lambda row: row["totalNetMs"], reverse=True),
        "topGross": sorted(rows, key=lambda row: row["totalGrossMs"], reverse=True),
        "topUnitsByNet": sorted(units.values(), key=lambda row: row["netMs"], reverse=True),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse a MaxProfiler summary capture.")
    parser.add_argument("--input", help="Path to a .maxprof file or a directory containing one.")
    parser.add_argument("--strings", help="Path to the sibling .strings file.")
    parser.add_argument("--meta", help="Path to the sibling .meta file.")
    parser.add_argument("--out", help="Optional JSON output path.")
    parser.add_argument("--top", type=int, default=20, help="Rows to print from topNet.")
    args = parser.parse_args()

    if not args.input:
        parser.print_help()
        return 0

    input_path = Path(args.input)
    if input_path.is_dir():
        profile_path = find_single(input_path, "*.maxprof")
    else:
        profile_path = input_path

    strings_path = Path(args.strings) if args.strings else profile_path.with_suffix(profile_path.suffix + ".strings")
    meta_path = Path(args.meta) if args.meta else profile_path.with_suffix(profile_path.suffix + ".meta")
    if not strings_path.exists():
        raise SystemExit(f"Missing strings file: {strings_path}")
    if not meta_path.exists():
        raise SystemExit(f"Missing meta file: {meta_path}")

    result = parse_summary(profile_path, strings_path, meta_path)
    if args.out:
        Path(args.out).write_text(json.dumps(result, indent=2), encoding="utf-8")

    for row in result["topNet"][: args.top]:
        print(
            f"{row['unit']} | {row['method']} | calls={row['callCount']} "
            f"gross={row['totalGrossMs']:.3f} net={row['totalNetMs']:.3f} "
            f"child={row['childMs']:.3f} self%={row['selfPct']:.2f}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
