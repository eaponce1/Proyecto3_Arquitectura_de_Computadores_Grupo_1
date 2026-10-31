#!/usr/bin/env python3
"""Summarize completed Stage 13 runs using only original STA and signoff metrics."""
import csv
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
reports = root / "reports/stage13"
cases = [
    ("reference", "etapa12_rom_ram_no_delay_ss", root / "reports/stage12"),
    ("D1 post-GRT", "etapa13_rom_ram_postgrt", reports),
    ("C1 clock", "etapa13_rom_ram_cts_retry", reports),
    ("DC1 combined", "etapa13_rom_ram_combined", reports),
]
rows, timing = [], []
for label, tag, report_root in cases:
    path = report_root / tag / "summary.json"
    if not path.is_file():
        continue
    summary = json.loads(path.read_text(encoding="utf-8"))
    corners = summary["corners"]
    if len(corners) != 9:
        raise RuntimeError(f"{tag}: only {len(corners)} corners")
    metrics = summary["selected_metrics"]
    grt_logs = sorted((root / "asic/runs" / tag).glob("*-openroad-globalrouting/openroad-globalrouting.log"))
    congestion = None
    if grt_logs:
        found = re.findall(r"^Total\s+\d+\s+\d+\s+([\d.]+)%\s+(\d+)\s*/\s*(\d+)\s*/\s*(\d+)",
                           grt_logs[-1].read_text(errors="replace"), re.M)
        if found:
            congestion = found[-1]
    row = dict(
        experiment=label, tag=tag, finished=(root / "asic/runs" / tag / "final/metrics.json").is_file(),
        slew=max(c["slew_metric_count"] for c in corners),
        cap=max(c["capacitance_metric_count"] for c in corners),
        fanout=max(c["fanout_metric_count"] for c in corners),
        worst_slew_ns=max((c["slew_worst_value"] for c in corners
                           if c["slew_worst_value"] is not None), default=None),
        worst_cap_pf=max((c["capacitance_worst_value"] for c in corners
                          if c["capacitance_worst_value"] is not None), default=None),
        worst_fanout=max((c["fanout_worst_value"] for c in corners
                          if c["fanout_worst_value"] is not None), default=None),
        setup_ws_ns=min(c["setup_ws_ns"] for c in corners),
        hold_ws_ns=min(c["hold_ws_ns"] for c in corners),
        setup_wns_ns=min(c["setup_wns_ns"] for c in corners),
        hold_wns_ns=min(c["hold_wns_ns"] for c in corners),
        setup_tns_ns=min(c["setup_tns_ns"] for c in corners),
        hold_tns_ns=min(c["hold_tns_ns"] for c in corners),
        stdcell_um2=metrics.get("design__instance__area__stdcell"),
        die_um2=metrics.get("design__die__area"),
        utilization_pct=100 * metrics.get("design__instance__utilization", 0),
        grt_usage_pct=None if congestion is None else float(congestion[0]),
        grt_overflow=None if congestion is None else "/".join(congestion[1:]),
        routing_drc=metrics.get("route__drc_errors"),
        magic_drc=metrics.get("magic__drc_error__count"),
        lvs=metrics.get("design__lvs_error__count"),
        antenna_nets=metrics.get("antenna__violating__nets"),
        synthesis_identical=summary["synthesis_identity"]["equal_after_hierarchy_name_normalization"],
    )
    rows.append(row)
    timing.extend(dict(experiment=label, tag=tag, **corner) for corner in corners)
if not rows:
    raise SystemExit("No complete reference or candidate reports")
for name, entries in (("comparison.csv", rows), ("timing_nine_corners.csv", timing)):
    with (reports / name).open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(entries[0]))
        writer.writeheader()
        writer.writerows(entries)
(reports / "comparison.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
print(json.dumps(rows, indent=2))
