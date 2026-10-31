#!/usr/bin/env python3
"""Aggregate LibreLane electrical violations by physical net and root class."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


OUTPUT_PINS = {"Z", "ZN", "Q", "QN", "Q_N", "Y", "CO", "S"}
TOP_INPUTS = {
    "clk_i",
    "rst_ni",
    "spi_cs_n_i",
    "spi_mosi_i",
    "spi_sclk_i",
    "btn_i[0]",
    "btn_i[1]",
    "btn_i[2]",
    "btn_i[3]",
}


def parse_netlist(path: Path):
    text = path.read_text(encoding="utf-8")
    instances = {}
    drivers = defaultdict(list)
    cell_re = re.compile(
        r"^\s*(gf180mcu\S+)\s+(\S+)\s*\((.*?)\);", re.MULTILINE | re.DOTALL
    )
    pin_re = re.compile(r"\.([A-Za-z0-9_]+)\s*\(\s*([^()]+?)\s*\)")
    for match in cell_re.finditer(text):
        cell, instance, body = match.groups()
        pins = dict(pin_re.findall(body))
        instances[instance] = (cell, pins)
        for pin, signal in pins.items():
            if pin in OUTPUT_PINS:
                drivers[signal].append((instance, cell, pin))
    return instances, drivers


def section_rows(report: str, heading: str, next_heading: str | None):
    marker = f"\n{heading}\n"
    start = report.find(marker)
    if start < 0:
        return []
    if next_heading:
        next_marker = f"\n{next_heading}\n"
        end = report.find(next_marker, start + len(marker))
        if end < 0:
            following = re.search(r"\nmax [^\n]+\n", report[start + len(marker) :])
            end = (
                start + len(marker) + following.start()
                if following is not None
                else len(report)
            )
    else:
        end = len(report)
    rows = []
    pattern = re.compile(
        r"^(\S+)\s+([\d.]+)\s+([\d.]+)\s+(-?[\d.]+) \(VIOLATED\)",
        re.MULTILINE,
    )
    for match in pattern.finditer(report[start:end]):
        pin, limit, value, slack = match.groups()
        rows.append(
            {
                "pin": pin,
                "limit": float(limit),
                "value": float(value),
                "slack": float(slack),
            }
        )
    return rows


def named_roots(signal, instances, drivers, depth=0, seen=None):
    seen = set() if seen is None else seen
    if not signal or signal in seen or depth > 14:
        return set()
    seen = seen | {signal}
    if signal in TOP_INPUTS or signal.startswith("btn_i["):
        return {signal}
    if signal.startswith("\\"):
        return {signal}
    result = set()
    for instance, _, _ in drivers.get(signal, []):
        for pin, source in instances[instance][1].items():
            if pin not in OUTPUT_PINS:
                result.update(named_roots(source, instances, drivers, depth + 1, seen))
    return result


def classify(net, roots, driver_instances):
    joined = " ".join(roots)
    classes = []
    if net.startswith("clknet_") or any(name.startswith("clkbuf") for name in driver_instances):
        classes.append("clock/CTS")
    if "rst_ni" in roots:
        classes.append("reset")
    if any(root.startswith(("btn_i[", "spi_")) for root in roots):
        classes.append("input/SPI")
    if "u_game_rom" in joined or "a_rdata_o" in joined or "pc_" in joined:
        classes.append("instruction/ROM/fetch")
    if "b_rdata_o" in joined or "data_q" in joined or "data_wdata" in joined:
        classes.append("data-memory")
    if "g_asic_regfile" in joined:
        classes.append("register-file")
    if "u_periph" in joined or "per_rdata" in joined:
        classes.append("peripheral")
    if not classes:
        classes.append("other-combinational")
    return "+".join(classes)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("run", type=Path)
    parser.add_argument("--corner", default="max_ss_125C_4v50")
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    args = parser.parse_args()

    sta_steps = sorted(args.run.glob("*-openroad-stapostpnr"))
    if not sta_steps:
        raise SystemExit("No OpenROAD.STAPostPNR step found")
    report_path = sta_steps[-1] / args.corner / "checks.rpt"
    netlist_path = args.run / "final/nl/asic_top.nl.v"
    report = report_path.read_text(encoding="utf-8")
    instances, drivers = parse_netlist(netlist_path)

    groups = {
        "slew": section_rows(report, "max slew", "max fanout"),
        "fanout": section_rows(report, "max fanout", "max capacitance"),
        "capacitance": section_rows(report, "max capacitance", "report_parasitic_annotation"),
    }
    aggregates = {}
    classification_counts = {}
    for violation_type, rows in groups.items():
        by_net = {}
        class_counter = Counter()
        for row in rows:
            if "/" in row["pin"]:
                instance, pin = row["pin"].rsplit("/", 1)
                cell, pins = instances.get(instance, ("PORT", {}))
                net = pins.get(pin, row["pin"])
            else:
                instance, pin, cell, net = row["pin"], "", "PORT", row["pin"]
            driver_data = drivers.get(net, [])
            driver_instances = [entry[0] for entry in driver_data]
            roots = named_roots(net, instances, drivers)
            category = classify(net, roots, driver_instances)
            class_counter[category] += 1
            entry = by_net.setdefault(
                net,
                {
                    "type": violation_type,
                    "net": net,
                    "count": 0,
                    "worst_slack": row["slack"],
                    "worst_value": row["value"],
                    "limit": row["limit"],
                    "drivers": ";".join(
                        f"{name}/{out_pin}:{driver_cell}"
                        for name, driver_cell, out_pin in driver_data
                    ),
                    "classification": category,
                    "sample_pin": row["pin"],
                    "roots": ";".join(sorted(roots)),
                },
            )
            entry["count"] += 1
            if row["slack"] < entry["worst_slack"]:
                entry["worst_slack"] = row["slack"]
                entry["worst_value"] = row["value"]
                entry["limit"] = row["limit"]
                entry["sample_pin"] = row["pin"]
        aggregates[violation_type] = sorted(
            by_net.values(), key=lambda item: (-item["count"], item["worst_slack"])
        )
        classification_counts[violation_type] = dict(class_counter.most_common())

    args.csv.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "type",
        "net",
        "count",
        "worst_value",
        "limit",
        "worst_slack",
        "drivers",
        "classification",
        "sample_pin",
        "roots",
    ]
    with args.csv.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for violation_type in ("slew", "capacitance", "fanout"):
            writer.writerows(aggregates[violation_type])

    payload = {
        "run": str(args.run),
        "corner": args.corner,
        "report": str(report_path),
        "totals": {key: len(value) for key, value in groups.items()},
        "classification_counts": classification_counts,
        "top10_slew_nets": aggregates["slew"][:10],
        "capacitance_nets": aggregates["capacitance"],
        "top10_fanout_nets": aggregates["fanout"][:10],
    }
    args.json.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(payload, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
