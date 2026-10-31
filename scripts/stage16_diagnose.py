#!/usr/bin/env python3
"""Extract post-route Stage 16 slew violations and group them by physical net."""
import csv
import re
import argparse
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("--tag", default="etapa15_eco_combined")
TAG = parser.parse_args().tag
RUN = ROOT / "asic/runs" / TAG
NETLIST = RUN / "final/nl/asic_top.nl.v"
OUT = ROOT / "reports/stage16"
OUT.mkdir(parents=True, exist_ok=True)

# Parse flattened Liberty-cell instances from the final physical netlist.
pin_to_net = {}
inst_cell = {}
block_re = re.compile(r"^[ \t]*([A-Za-z0-9_]+)[ \t]+(\S+)[ \t]*\(([\s\S]*?)\);", re.M)
text = NETLIST.read_text(encoding="utf-8", errors="replace")
for match in block_re.finditer(text):
    cell, inst, body = match.groups()
    if "gf180mcu_fd_sc_mcu7t5v0__" not in cell:
        continue
    inst_cell[inst] = cell
    for pin, net in re.findall(r"\.([A-Za-z0-9_]+)\s*\(\s*([^()]+?)\s*\)", body):
        pin_to_net[f"{inst}/{pin}"] = net.strip()

output_pins = {"Z", "ZN", "Q", "QN", "CO", "COB", "S", "SO", "O", "Y", "X"}
net_drivers = defaultdict(list)
inst_pins = defaultdict(list)
for inst_pin, net in pin_to_net.items():
    inst, pin = inst_pin.rsplit("/", 1)
    inst_pins[inst].append((pin, net))
    if pin in output_pins:
        net_drivers[net].append(f"{inst}/{pin} ({inst_cell.get(inst, '<unknown>')})")

def classify(net):
    """Best-effort upstream classification from final flattened net names."""
    seen = set(); queue = [net]; hits = set()
    while queue and len(seen) < 500:
        current = queue.pop()
        if current in seen: continue
        seen.add(current)
        low = current.lower()
        if "clk" in low: hits.add("clock")
        if "rst" in low or "reset" in low: hits.add("reset")
        if "a_rdata_o" in low or "instruction" in low or "rom" in low: hits.add("instruction/ROM")
        if "data_wdata" in low or "data_rdata" in low or "u_rf" in low or "bank_a" in low or "bank_b" in low: hits.add("data/register-file")
        for driver in net_drivers.get(current, []):
            inst = driver.split("/", 1)[0]
            for pin, upstream in inst_pins.get(inst, []):
                # Do not walk clock/reset control pins when classifying a data cone.
                if pin not in output_pins and pin.upper() not in {"CLK", "RN", "RESET", "RESET_B"}:
                    queue.append(upstream)
    return ";".join(sorted(hits)) or "internal/unknown"

rows = []
for corner_dir in sorted(p for p in (RUN / "13-openroad-stapostpnr").iterdir() if p.is_dir()):
    rpt = corner_dir / "checks.rpt"
    section = None
    for line_no, line in enumerate(rpt.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        if line.strip() == "max slew":
            section = "slew"
            continue
        if line.startswith("max capacitance") or line.startswith("max fanout"):
            section = None
        if section != "slew" or "(VIOLATED)" not in line:
            continue
        m = re.match(r"\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)", line)
        if not m:
            continue
        pin, limit, value, slack = m.groups()
        rows.append({
            "corner": corner_dir.name, "line": line_no, "pin": pin,
            "limit_ns": float(limit), "slew_ns": float(value), "slack_ns": float(slack),
            "net": pin_to_net.get(pin, "<unmapped>"),
            "instance": pin.split("/", 1)[0],
            "cell": inst_cell.get(pin.split("/", 1)[0], "<unknown>"),
            "classification": classify(pin_to_net.get(pin, "<unmapped>")),
        })

with (OUT / "slew_violations.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0]))
    writer.writeheader(); writer.writerows(rows)

by_net = defaultdict(list)
for row in rows:
    by_net[row["net"]].append(row)
summary = []
for net, net_rows in by_net.items():
    worst = max(net_rows, key=lambda r: r["slew_ns"])
    summary.append({
        "net": net, "violations": len(net_rows),
        "corners": ",".join(sorted({r["corner"] for r in net_rows})),
        "worst_slew_ns": worst["slew_ns"], "limit_ns": worst["limit_ns"],
        "worst_slack_ns": worst["slack_ns"],
        "pins": ",".join(sorted({r["pin"] for r in net_rows})),
        "cells": ",".join(sorted({r["cell"] for r in net_rows})),
        "drivers": ",".join(sorted(net_drivers.get(net, []))),
        "classification": classify(net),
    })
summary.sort(key=lambda r: (-r["violations"], -r["worst_slew_ns"]))
with (OUT / "slew_by_net.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=list(summary[0])); writer.writeheader(); writer.writerows(summary)

print(f"violations={len(rows)} unique_pins={len({r['pin'] for r in rows})} unique_nets={len(summary)}")
for item in summary[:20]:
    print(item["violations"], item["net"], item["worst_slew_ns"], item["cells"])
