#!/usr/bin/env python3
"""Annotate a LibreLane KLayout render using netlist-to-DEF traceability."""

from __future__ import annotations

import argparse
import base64
import csv
import re
from pathlib import Path


OUTPUT_PINS = {"Z", "ZN", "Q", "QN", "Q_N", "Y", "CO", "S"}


def parse_netlist(path: Path):
    text = path.read_text(encoding="utf-8")
    instances = {}
    drivers = {}
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
                drivers.setdefault(signal, []).append(instance)
    return instances, drivers


def parse_def(path: Path):
    text = path.read_text(encoding="utf-8")
    units_match = re.search(r"UNITS DISTANCE MICRONS\s+(\d+)\s*;", text)
    die_match = re.search(
        r"DIEAREA\s+\(\s*(\d+)\s+(\d+)\s*\)\s+\(\s*(\d+)\s+(\d+)\s*\)\s*;",
        text,
    )
    if not units_match or not die_match:
        raise RuntimeError("DEF without UNITS/DIEAREA")
    positions = {
        match.group(1): (int(match.group(2)), int(match.group(3)))
        for match in re.finditer(
            r"^\s*-\s+(\S+)\s+\S+\s+\+\s+(?:PLACED|FIXED)\s+"
            r"\(\s*(\d+)\s+(\d+)\s*\)",
            text,
            re.MULTILINE,
        )
    }
    return int(units_match.group(1)), tuple(map(int, die_match.groups())), positions


def find_groups(instances, drivers):
    register_file = set()
    cycle_counter = set()
    for instance, (_, pins) in instances.items():
        for pin, signal in pins.items():
            if pin not in OUTPUT_PINS:
                continue
            if "g_asic_regfile.u_rf.bank_a" in signal:
                register_file.add(instance)
            if "u_periph.cycle_q" in signal:
                cycle_counter.add(instance)

    # alu_result is optimized away as a name. Its 32 output bits remain visible
    # at the data-memory address interface, which is driven directly by the ALU.
    alu_outputs = set()
    for signal, signal_drivers in drivers.items():
        if "g_rom_ram_memory.u_ram.a_addr_i[" in signal:
            alu_outputs.update(signal_drivers)

    return {
        "Register file": register_file,
        "ALU (drivers de a_addr_i)": alu_outputs,
        "Contador de ciclos": cycle_counter,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("run", type=Path, help="LibreLane run directory")
    parser.add_argument("output", type=Path, help="Output SVG")
    parser.add_argument("--csv", type=Path, required=True, help="Traceability CSV")
    args = parser.parse_args()

    netlist = args.run / "final/nl/asic_top.nl.v"
    def_file = args.run / "final/def/asic_top.def"
    render = args.run / "final/render/asic_top.png"
    instances, drivers = parse_netlist(netlist)
    units, (x0, y0, x1, y1), positions = parse_def(def_file)
    groups = find_groups(instances, drivers)

    width = 1000.0
    height = width * (y1 - y0) / (x1 - x0)
    palette = {
        "Register file": ("#ff3b30", 1.7, 0.34),
        "ALU (drivers de a_addr_i)": ("#ffd60a", 4.2, 0.90),
        "Contador de ciclos": ("#00e5ff", 3.2, 0.88),
    }

    def xy(position):
        x, y = position
        return (
            (x - x0) * width / (x1 - x0),
            height - (y - y0) * height / (y1 - y0),
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    with args.csv.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["bloque", "instancia", "celda", "x_um", "y_um", "evidencia"])
        for group, names in groups.items():
            for name in sorted(names):
                if name not in positions:
                    continue
                x, y = positions[name]
                cell, pins = instances[name]
                evidence = "; ".join(
                    f"{pin}={signal}"
                    for pin, signal in pins.items()
                    if pin in OUTPUT_PINS
                )
                writer.writerow([group, name, cell, x / units, y / units, evidence])

    encoded = base64.b64encode(render.read_bytes()).decode("ascii")
    svg = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="{height:.2f}" viewBox="0 0 1000 {height:.2f}">',
        f'<image width="1000" height="{height:.2f}" href="data:image/png;base64,{encoded}"/>',
        '<rect x="0" y="0" width="1000" height="100%" fill="none" stroke="white" stroke-width="2"/>',
    ]
    for group, names in groups.items():
        color, radius, opacity = palette[group]
        plotted = [positions[name] for name in names if name in positions]
        for position in plotted:
            x, y = xy(position)
            svg.append(
                f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{radius}" fill="{color}" fill-opacity="{opacity}"/>'
            )
        if plotted:
            cx = sum(xy(pos)[0] for pos in plotted) / len(plotted)
            cy = sum(xy(pos)[1] for pos in plotted) / len(plotted)
            svg += [
                f'<line x1="{cx:.2f}" y1="{cy:.2f}" x2="{min(cx + 105, 820):.2f}" y2="{max(cy - 52, 45):.2f}" stroke="{color}" stroke-width="3"/>',
                f'<rect x="{min(cx + 100, 815):.2f}" y="{max(cy - 76, 20):.2f}" width="180" height="31" rx="5" fill="#111" fill-opacity="0.82" stroke="{color}"/>',
                f'<text x="{min(cx + 108, 823):.2f}" y="{max(cy - 55, 41):.2f}" fill="white" font-family="sans-serif" font-size="14">{group} ({len(plotted)})</text>',
            ]
    svg += [
        '<rect x="12" y="12" width="390" height="30" rx="5" fill="#111" fill-opacity="0.86"/>',
        '<text x="22" y="33" fill="white" font-family="sans-serif" font-size="15">KLayout real + trazabilidad netlist/DEF (coordenadas de celdas)</text>',
        "</svg>",
    ]
    args.output.write_text("\n".join(svg), encoding="utf-8")
    for group, names in groups.items():
        print(f"{group}: {sum(name in positions for name in names)} instances")


if __name__ == "__main__":
    main()
