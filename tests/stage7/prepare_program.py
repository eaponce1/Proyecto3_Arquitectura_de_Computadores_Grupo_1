#!/usr/bin/env python3
"""Create the accelerated Stage 7 program without editing the deliverable."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "sw" / "game_asic_100ns.s"
OUTPUT = ROOT / "tests" / "stage7" / "generated" / "game_stage7.s"


def main():
    text = SOURCE.read_text(encoding="utf-8")
    replacements = {
        "lui   x2, 0x1C9C\naddi  x2, x2, 896          # x2 = CICLOS_3S = 30 000 000":
            "addi  x2, x0, 300          # STAGE7: espera reducida, misma logica",
        "lui   x3, 0xF4\naddi  x3, x3, 576          # x3 = CYCLES_PER_TENTH = 1 000 000":
            "addi  x3, x0, 100          # STAGE7: decima escalada, misma logica",
    }
    for old, new in replacements.items():
        if text.count(old) != 1:
            raise SystemExit(f"patron fuente inesperado: {old.splitlines()[0]}")
        text = text.replace(old, new)
    banner = (
        "# GENERATED FOR STAGE 7 ONLY. Source: sw/game_asic_100ns.s\n"
        "# Wait constants scaled from 30,000,000/1,000,000 to 300/100 cycles.\n"
    )
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(banner + text, encoding="utf-8")
    print(OUTPUT.relative_to(ROOT))


if __name__ == "__main__":
    main()
