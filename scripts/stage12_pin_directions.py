#!/usr/bin/env python3
"""Extract actual GF180 Liberty signal-pin directions for electrical tracing."""
import argparse
import hashlib
import json
import re
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument("liberty", type=Path)
p.add_argument("--output", required=True, type=Path)
args = p.parse_args()
raw = args.liberty.read_bytes()
text = re.sub(r"/\*.*?\*/", "", raw.decode(), flags=re.S)
cell_re = re.compile(r'\bcell\s*\(\s*"?([\w]+)"?\s*\)\s*\{')
pin_re = re.compile(r'\bpin\s*\(\s*"?([\w\[\]]+)"?\s*\)\s*\{')
cell_matches = list(cell_re.finditer(text))
directions = {}
for i, cell in enumerate(cell_matches):
    body = text[cell.end():cell_matches[i + 1].start() if i + 1 < len(cell_matches) else len(text)]
    pins = list(pin_re.finditer(body))
    table = {}
    for j, pin in enumerate(pins):
        section = body[pin.end():pins[j + 1].start() if j + 1 < len(pins) else len(body)]
        direction = re.search(r"\bdirection\s*:\s*(input|output|inout)\s*;", section)
        if direction:
            table[pin[1]] = direction[1]
    directions[cell[1]] = table
assert directions["gf180mcu_fd_sc_mcu7t5v0__mux2_2"]["S"] == "input"
assert directions["gf180mcu_fd_sc_mcu7t5v0__mux2_2"]["Z"] == "output"
payload = dict(source=str(args.liberty), sha256=hashlib.sha256(raw).hexdigest(), cells=directions)
args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps(payload, indent=2), encoding="utf-8")
print("Library pin directions saved:", len(directions), "cells;", args.output)

