#!/usr/bin/env python3
"""Compare the machine-readable Stage 7 result records from two executions."""

import argparse
from pathlib import Path


def records(path):
    return [line for line in Path(path).read_text().splitlines() if line.startswith("RESULT|")]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("rtl_log")
    parser.add_argument("gate_log")
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    rtl = records(args.rtl_log)
    gate = records(args.gate_log)
    passed = rtl == gate and len(rtl) >= 3
    report = [
        f"rtl_records={len(rtl)}",
        f"gate_records={len(gate)}",
        f"exact_match={str(passed).lower()}",
    ]
    if not passed:
        report.extend(["RTL:", *rtl, "GATE:", *gate])
    Path(args.output).write_text("\n".join(report) + "\n")
    print("\n".join(report))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
