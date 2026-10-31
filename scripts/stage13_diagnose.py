#!/usr/bin/env python3
"""Export every max-SS residual with its actual DEF placement and source line."""
import csv
import json
import re
from collections import Counter
from pathlib import Path

root = Path(__file__).resolve().parents[1]
tag = "etapa12_rom_ram_no_delay_ss"
source = root / "reports/stage12" / tag / "violations.json"
def_path = root / "asic/runs" / tag / "final/def/asic_top.def"
out = root / "reports/stage13"
out.mkdir(parents=True, exist_ok=True)

placements = {}
dbu = None
for line in def_path.open(encoding="utf-8"):
    if line.startswith("UNITS DISTANCE MICRONS "):
        dbu = int(re.search(r"MICRONS (\d+)", line).group(1))
    match = re.match(r"\s*-\s+(\S+)\s+\S+.*?\+ PLACED \( (\d+) (\d+) \)", line)
    if match:
        name, x, y = match.groups()
        placements[name] = (int(x), int(y))
assert dbu == 2000, dbu

records = [v for v in json.loads(source.read_text(encoding="utf-8"))
           if v["corner"] == "max_ss_125C_4v50"]
counts = Counter(v["type"] for v in records)
assert counts == {"slew": 440, "capacitance": 2, "fanout": 57}, counts
rows = []
for item in records:
    driver = item["drivers"][0] if item["drivers"] else ("", "", "")
    x, y = placements.get(driver[0], (None, None))
    sink_inst = item["pin"].split("/", 1)[0]
    sx, sy = placements.get(sink_inst, (None, None))
    rows.append(dict(
        kind=item["type"], net=item["net"], violating_pin=item["pin"],
        driver=driver[0], driver_cell=driver[1],
        driver_pin=driver[2], loads=len(item["loads"]),
        value=item["value"], limit=item["limit"], slack=item["slack"],
        driver_x_um=None if x is None else x / dbu,
        driver_y_um=None if y is None else y / dbu,
        pin_x_um=None if sx is None else sx / dbu,
        pin_y_um=None if sy is None else sy / dbu,
        classification=item["classification"],
        source=item["source"], source_line=item["line"],
    ))
with (out / "baseline_residual_pins.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)

net_rows = json.loads((root / "reports/stage12" / tag / "nets.json").read_text())
summary = {
    "source": str(source.relative_to(root)),
    "def": str(def_path.relative_to(root)),
    "def_dbu_per_um": dbu,
    "counts_max_ss": dict(counts),
    "slew_by_classification": dict(Counter(v["classification"] for v in records if v["type"] == "slew")),
    "worst_slew_nets": sorted((v for v in net_rows if v["type"] == "slew"),
                              key=lambda v: v["worst_slack"])[:10],
    "capacitance_nets": [v for v in net_rows if v["type"] == "capacitance"],
    "worst_fanout_nets": sorted((v for v in net_rows if v["type"] == "fanout"),
                                key=lambda v: v["worst_slack"])[:10],
}
(out / "baseline_residual_summary.json").write_text(
    json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print("max_ss:", dict(counts), "instances with DEF placements:", len(placements))
