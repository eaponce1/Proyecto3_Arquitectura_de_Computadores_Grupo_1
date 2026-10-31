#!/usr/bin/env python3
"""Read-only electrical worst-pin reports, including non-violating pins."""
import argparse
import concurrent.futures
import json
import os
import re
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("tag")
p.add_argument("--jobs", type=int, choices=(1, 2, 3), default=1)
p.add_argument("--reuse-existing", action="store_true")
args = p.parse_args()
out = root / "reports/stage12" / args.tag
audit = json.loads((out / "summary.json").read_text())
pdk = Path(os.environ.get("PDK_ROOT", str(Path.home() / ".ciel")))
def measure(corner_data):
    corner = corner_data["corner"]
    path = out / ("worst_" + corner + ".rpt")
    if path.exists() and not args.reuse_existing:
        raise RuntimeError("Refusing overwrite: " + str(path))
    cmd = ["docker", "run", "--rm",
           "-e", "STAGE12_TAG=" + args.tag, "-e", "STAGE12_CORNER=" + corner,
           "-v", str(root) + ":" + str(root),
           "-v", str(pdk) + ":" + str(pdk), "-w", str(root),
           "ghcr.io/librelane/librelane:3.0.16",
           "openroad", "-exit", "scripts/stage12_all_electrical.tcl"]
    if path.exists():
        output, return_code = path.read_text(), 0
    else:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output, return_code = proc.stdout, proc.returncode
        path.write_text(output, encoding="utf-8")
    if return_code or "[ERROR " in output or "STAGE12_ALL_ELECTRICAL_PINS" not in output:
        raise RuntimeError("STA failure; see " + str(path))
    result = dict(corner=corner, report=str(path.relative_to(root)))
    for mode, suffix in (("setup", "max"), ("hold", "min")):
        match = re.search("worst slack " + suffix + r"\s+(-?[\d.]+)", output)
        if not match:
            raise RuntimeError("Missing slack in " + str(path))
        value = float(match[1])
        # Cross-check only: 1 ps tolerance for independently exported netlist/SPEF.
        # Never used to accept a negative signoff slack or alter library limits.
        if abs(value - corner_data[mode + "_ws_ns"]) > 0.001:
            raise RuntimeError("Independent STA does not reproduce original slack: " + str(path))
        result[mode + "_ws_ns"] = value
    for typ, heading in (("slew", "max slew"), ("fanout", "max fanout"), ("capacitance", "max capacitance")):
        section = output.split("\n" + heading + "\n", 1)[1]
        row = re.search(r"^(\S+)\s+([\d.]+)\s+([\d.]+)\s+(-?[\d.]+)(.*)$", section, re.M)
        if not row:
            raise RuntimeError("Missing worst " + typ + " in " + str(path))
        result[typ] = dict(pin=row[1], limit=float(row[2]), value=float(row[3]),
                           slack=float(row[4]), status=row[5].strip())
    return result

with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
    values = list(pool.map(measure, audit["corners"]))
payload = dict(tag=args.tag, corners=values,
               independent_slack_comparison_tolerance_ns=0.001,
               worst_slew_ns=max(v["slew"]["value"] for v in values),
               worst_capacitance_pf=max(v["capacitance"]["value"] for v in values),
               worst_fanout=max(v["fanout"]["value"] for v in values))
(out / "independent_worst.json").write_text(json.dumps(payload, indent=2), encoding="utf-8")
print(json.dumps(payload, indent=2))

