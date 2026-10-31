#!/usr/bin/env python3
"""Read original reports, trace electrical drivers/loads and save Stage 12 evidence."""
import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from analyze_electrical import section_rows, TOP_INPUTS, classify

def parse_with_directions(path, directions):
    instances, drivers = {}, defaultdict(list)
    cell_re = re.compile(r"^\s*(gf180mcu\S+)\s+(\S+)\s*\((.*?)\);", re.M | re.S)
    pin_re = re.compile(r"\.([A-Za-z0-9_]+)\s*\(\s*([^()]+?)\s*\)")
    for match in cell_re.finditer(path.read_text(encoding="utf-8")):
        cell, inst, body = match.groups()
        if cell not in directions:
            raise ValueError("Missing Liberty directions for " + cell)
        pins = dict(pin_re.findall(body))
        instances[inst] = cell, pins
        for pin, net in pins.items():
            if directions[cell].get(pin) == "output":
                drivers[net].append((inst, cell, pin))
    return instances, drivers

def roots_of(net, instances, drivers, directions, depth=0, seen=None):
    seen = set() if seen is None else seen
    if net in seen or depth > 14:
        return set()
    if net.startswith("\\") or net in TOP_INPUTS or net.startswith("btn_i["):
        return {net}
    roots = set()
    for inst, cell, output in drivers.get(net, []):
        for pin, source in instances[inst][1].items():
            if directions[cell].get(pin) == "input":
                roots.update(roots_of(source, instances, drivers, directions, depth + 1, seen | {net}))
    return roots

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("tag")
    parser.add_argument("--report-root", default="reports/stage12")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    run = root / "asic/runs" / args.tag
    out = root / args.report_root / args.tag
    out.mkdir(parents=True, exist_ok=True)
    sta = sorted(run.glob("*-openroad-stapostpnr"))
    if not sta:
        raise SystemExit("No post-route STA: run not eligible for closure")
    netlist = run / "final/nl/asic_top.nl.v"
    if not netlist.exists():
        netlist = Path(json.loads((sta[-1] / "state_out.json").read_text())["nl"])
    direction_path = root / "reports/stage12/cell_pin_directions.json"
    direction_payload = json.loads(direction_path.read_text())
    directions = direction_payload["cells"]
    instances, drivers = parse_with_directions(netlist, directions)
    loads = defaultdict(list)
    for inst, (cell, pins) in instances.items():
        for pin, net in pins.items():
            if directions[cell].get(pin) == "input":
                loads[net].append({"instance": inst, "cell": cell, "pin": pin})
    roots_cache = {}
    records = []
    corners = []
    metrics_path = run / "final/metrics.json"
    metrics = json.loads(metrics_path.read_text()) if metrics_path.exists() else json.loads((sta[-1] / "state_out.json").read_text())["metrics"]
    for corner_dir in sorted(sta[-1].iterdir()):
        report_path = corner_dir / "checks.rpt"
        if not report_path.is_file():
            continue
        report = report_path.read_text()
        corner = corner_dir.name
        summary = {"corner": corner}
        for mode in ("setup", "hold"):
            for metric in ("ws", "wns", "tns"):
                summary[mode + "_" + metric + "_ns"] = metrics.get("timing__" + mode + "__" + metric + "__corner:" + corner)
        for typ, heading, following, metric_key in (
            ("slew", "max slew", "max fanout", "max_slew"),
            ("fanout", "max fanout", "max capacitance", "max_fanout"),
            ("capacitance", "max capacitance", "report_parasitic_annotation", "max_cap"),
        ):
            rows = section_rows(report, heading, following)
            summary[typ + "_report_count"] = len(rows)
            summary[typ + "_metric_count"] = metrics.get("design__" + metric_key + "_violation__count__corner:" + corner)
            summary[typ + "_worst_value"] = max((r["value"] for r in rows), default=None)
            summary[typ + "_worst_slack"] = min((r["slack"] for r in rows), default=0)
            for row in rows:
                inst, sep, pin = row["pin"].rpartition("/")
                net = instances.get(inst, ("PORT", {}))[1].get(pin, row["pin"]) if sep else row["pin"]
                if net not in roots_cache:
                    roots_cache[net] = sorted(roots_of(net, instances, drivers, directions))
                row.update(type=typ, corner=corner, net=net,
                           drivers=drivers.get(net, []), loads=loads.get(net, []),
                           roots=roots_cache[net],
                           classification=classify(net, set(roots_cache[net]), [d[0] for d in drivers.get(net, [])]),
                           source=str(report_path.relative_to(root)),
                           line=next((i for i, line in enumerate(report.splitlines(), 1) if line.startswith(row["pin"] + " ") and "(VIOLATED)" in line), None))
                records.append(row)
        corners.append(summary)
    fields = list(corners[0])
    with (out / "corners.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields); writer.writeheader(); writer.writerows(corners)
    (out / "violations.json").write_text(json.dumps(records, indent=2), encoding="utf-8")
    grouped = defaultdict(list)
    for row in records:
        if row["corner"] == "max_ss_125C_4v50":
            grouped[(row["type"], row["net"])].append(row)
    nets = []
    for (typ, net), rows in grouped.items():
        worst = min(rows, key=lambda x: x["slack"])
        nets.append(dict(type=typ, net=net, count=len(rows), worst_value=worst["value"],
                         worst_slack=worst["slack"], limit=worst["limit"],
                         drivers=worst["drivers"], loads=worst["loads"],
                         roots=worst["roots"], classification=worst["classification"],
                         source=worst["source"], line=worst["line"]))
    nets.sort(key=lambda x: (x["type"], -x["count"], x["worst_slack"]))
    (out / "nets.json").write_text(json.dumps(nets, indent=2), encoding="utf-8")
    baseline_synth = root / "asic/runs/etapa9_rom_ram_util40_debounce/06-yosys-synthesis/asic_top.nl.v"
    candidate_synth = run / "06-yosys-synthesis/asic_top.nl.v"
    baseline_text = baseline_synth.read_text()
    candidate_text = candidate_synth.read_text()
    normalized_text = candidate_text.replace("u_core.genblk1.g_asic_regfile", "u_core.g_asic_regfile")
    synthesis_identity = dict(
        equal_after_hierarchy_name_normalization=(baseline_text == normalized_text),
        normalization="u_core.genblk1.g_asic_regfile -> u_core.g_asic_regfile",
        baseline_sha256=hashlib.sha256(baseline_text.encode()).hexdigest(),
        normalized_candidate_sha256=hashlib.sha256(normalized_text.encode()).hexdigest())
    classifications = {typ: dict(Counter(row["classification"] for row in records if row["corner"] == "max_ss_125C_4v50" and row["type"] == typ))
                       for typ in ("slew", "capacitance", "fanout")}
    result = dict(tag=args.tag, corners=corners, synthesis_identity=synthesis_identity,
                  classification_counts=classifications,
                  pin_directions_source=direction_payload["source"],
                  pin_directions_sha256=direction_payload["sha256"],
                  selected_metrics={k:v for k,v in metrics.items() if any(s in k for s in ("area", "utilization", "drc", "antenna", "lvs", "wirelength", "max_slew", "max_cap", "max_fanout"))},
                  cell_types=dict(Counter(cell for cell, pins in instances.values())),
                  sequential_cells=sum(1 for cell,pins in instances.values() if "__dff" in cell),
                  netlist_sha256=hashlib.sha256(netlist.read_bytes()).hexdigest())
    (out / "summary.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(dict(tag=args.tag, corners=corners), indent=2))

if __name__ == "__main__":
    main()

