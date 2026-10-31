#!/usr/bin/env python3
"""Extract auditable hierarchical and cycle-counter areas from Yosys JSON."""

import argparse
import json
import re
from collections import Counter
from pathlib import Path


def liberty_areas(path):
    areas = {}
    cell = None
    depth = 0
    for raw in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.match(r"\s*cell\s*\(\s*([^\s)]+)\s*\)\s*\{", raw)
        if match and cell is None:
            cell = match.group(1)
            depth = raw.count("{") - raw.count("}")
            continue
        if cell is not None:
            area = re.match(r"\s*area\s*:\s*([0-9.eE+-]+)\s*;", raw)
            if area:
                areas[cell] = float(area.group(1))
            depth += raw.count("{") - raw.count("}")
            if depth == 0:
                cell = None
    return areas


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mapped_json", type=Path)
    parser.add_argument("stat_json", type=Path)
    parser.add_argument("liberty", type=Path)
    parser.add_argument("--flat-json", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    mapped = json.loads(args.mapped_json.read_text(encoding="utf-8"))
    stats = json.loads(args.stat_json.read_text(encoding="utf-8"))
    areas = liberty_areas(args.liberty)
    module = mapped["modules"]["pochoco_periph"]

    counter_bits = set()
    for name, net in module["netnames"].items():
        if re.fullmatch(r"cycle_q(?:\[\d+\])?", name):
            counter_bits.update(bit for bit in net["bits"] if isinstance(bit, int))
    if len(counter_bits) != 32:
        raise SystemExit(f"se esperaban 32 bits cycle_q, se encontraron {len(counter_bits)}")

    drivers = {}
    counter_registers = set()
    for name, cell in module["cells"].items():
        for port, direction in cell["port_directions"].items():
            if direction == "output":
                for bit in cell["connections"][port]:
                    if isinstance(bit, int):
                        drivers[bit] = name
                        if bit in counter_bits:
                            counter_registers.add(name)

    if len(counter_registers) != 32:
        raise SystemExit(
            f"se esperaban 32 FF de cycle_q, se encontraron {len(counter_registers)}"
        )

    cone = set(counter_registers)
    pending = []
    for name in counter_registers:
        cell = module["cells"][name]
        for port, direction in cell["port_directions"].items():
            if direction == "input" and port == "D":
                pending.extend(cell["connections"][port])

    while pending:
        bit = pending.pop()
        if not isinstance(bit, int) or bit in counter_bits:
            continue
        name = drivers.get(bit)
        if name is None or name in cone:
            continue
        cell = module["cells"][name]
        if "dff" in cell["type"] or "lat" in cell["type"]:
            continue
        cone.add(name)
        for port, direction in cell["port_directions"].items():
            if direction == "input":
                pending.extend(cell["connections"][port])

    by_type = Counter(module["cells"][name]["type"] for name in cone)
    missing = sorted(cell_type for cell_type in by_type if cell_type not in areas)
    if missing:
        raise SystemExit(f"areas Liberty ausentes: {missing}")
    counter_area = sum(areas[cell_type] * count for cell_type, count in by_type.items())
    design_area = stats["design"]["area"]

    result = {
        "method": "backward cone from the 32 mapped cycle_q flip-flops in hierarchy-preserved pochoco_periph",
        "counter_register_bits": len(counter_registers),
        "counter_cells": sum(by_type.values()),
        "counter_cells_by_type": dict(sorted(by_type.items())),
        "counter_area_um2": counter_area,
        "hierarchical_design_area_um2": design_area,
        "counter_fraction_percent": 100.0 * counter_area / design_area,
        "register_file_area_um2": stats["modules"]["\\espino_register_file_ff"]["area"],
        "alu_area_um2": stats["modules"]["\\espino_alu"]["area"],
        "largest_leaf_module": "espino_register_file_ff",
        "modules": {
            name: data.get("area", 0.0) for name, data in stats["modules"].items()
        },
    }
    if args.flat_json:
        flat = json.loads(args.flat_json.read_text(encoding="utf-8"))
        flat_types = Counter(
            cell["type"] for cell in flat["modules"]["asic_top"]["cells"].values()
        )
        result["flat_final_cell_count"] = sum(flat_types.values())
        result["flat_final_top_five_cells"] = [
            {"cell": cell_type, "count": count}
            for cell_type, count in flat_types.most_common(5)
        ]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
