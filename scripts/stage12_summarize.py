#!/usr/bin/env python3
"""Consolidate Stage 12 audits without inventing metrics for incomplete runs."""
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
reports = root / "reports/stage12"
tags = ["etapa9_rom_ram_util40_debounce", "etapa12_rom_ram_no_dlyb",
        "etapa12_rom_ram_no_delay", "etapa12_rom_ram_no_delay_ss"]
rows, timing = [], []
for tag in tags:
    path = reports / tag / "summary.json"
    if not path.exists():
        continue
    data = json.loads(path.read_text())
    m = data["selected_metrics"]
    cs = data["corners"]
    row = dict(
        tag=tag, slew=max(c["slew_metric_count"] for c in cs),
        capacitance=max(c["capacitance_metric_count"] for c in cs),
        fanout=max(c["fanout_metric_count"] for c in cs),
        worst_violating_slew_ns=max((c["slew_worst_value"] for c in cs if c["slew_worst_value"] is not None), default=None),
        setup_ws_ns=min(c["setup_ws_ns"] for c in cs),
        hold_ws_ns=min(c["hold_ws_ns"] for c in cs),
        setup_wns_ns=min(c["setup_wns_ns"] for c in cs),
        hold_wns_ns=min(c["hold_wns_ns"] for c in cs),
        setup_tns_ns=min(c["setup_tns_ns"] for c in cs),
        hold_tns_ns=min(c["hold_tns_ns"] for c in cs),
        stdcell_um2=m["design__instance__area__stdcell"],
        die_um2=m["design__die__area"],
        utilization_percent=100*m["design__instance__utilization"],
        routing_drc=m.get("route__drc_errors"),
        magic_drc=m.get("magic__drc_error__count"),
        lvs=m.get("design__lvs_error__count"),
        antenna_nets=m.get("antenna__violating__nets"),
        global_wire_um=m.get("global_route__wirelength"),
        route_wire_um=m.get("route__wirelength"),
        all_nine_corners=len(cs) == 9,
        synthesis_same=data["synthesis_identity"]["equal_after_hierarchy_name_normalization"])
    rows.append(row)
    timing.extend(dict(tag=tag, **corner) for corner in cs)
for name, data in (("comparison.csv", rows), ("timing_nine_corners.csv", timing)):
    with (reports / name).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(data[0]))
        writer.writeheader()
        writer.writerows(data)
(reports / "comparison.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
print(json.dumps(rows, indent=2))

