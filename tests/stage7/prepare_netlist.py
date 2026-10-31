#!/usr/bin/env python3
"""Rename only the synthesized top so RTL and gates can be cosimulated."""

import argparse
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "asic" / "runs" / "etapa7_rom_ram_post_synth" / "06-yosys-synthesis" / "asic_top.nl.v"
DEFAULT_OUTPUT = ROOT / "tests" / "stage7" / "generated" / "asic_top_gate.nl.v"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    source = args.source if args.source.is_absolute() else ROOT / args.source
    output = args.output if args.output.is_absolute() else ROOT / args.output
    text = source.read_text(encoding="utf-8")
    matches = list(re.finditer(r"module\s+asic_top\s*\(", text))
    if len(matches) != 1:
        raise SystemExit("no se encontro un unico modulo superior asic_top")
    output.parent.mkdir(parents=True, exist_ok=True)
    start, end = matches[0].span()
    output.write_text(text[:start] + "module asic_top_gate(" + text[end:], encoding="utf-8")
    print(output.relative_to(ROOT))


if __name__ == "__main__":
    main()
