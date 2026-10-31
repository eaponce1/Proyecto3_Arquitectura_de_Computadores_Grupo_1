#!/usr/bin/env python3
"""Launch one immutable Stage 13 LibreLane candidate and retain its full log."""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument("config")
parser.add_argument("--tag", required=True)
args = parser.parse_args()
if not args.tag.startswith("etapa13_") or "/" in args.tag or "\\" in args.tag:
    raise SystemExit("Expected a simple etapa13_ run tag")
os.chdir(root)
config_path = (root / args.config).resolve()
config = json.loads(config_path.read_text(encoding="utf-8"))
reference = json.loads((root / "asic/rom_ram_stage12_no_delay_ss.json").read_text())
if config["CLOCK_PERIOD"] != 100 or config["FP_CORE_UTIL"] != 40:
    raise SystemExit("Clock and core utilization must remain 100 ns and 40 %")
if config["VERILOG_FILES"] != reference["VERILOG_FILES"] or config["SYNTH_PARAMETERS"] != reference["SYNTH_PARAMETERS"]:
    raise SystemExit("Functional source list or memory architecture changed")
if config["STD_CELL_LIBRARY"] != reference["STD_CELL_LIBRARY"] or config["PDK"] != reference["PDK"]:
    raise SystemExit("PDK/library mismatch")
if config["EXTRA_EXCLUDED_CELLS"] != reference["EXTRA_EXCLUDED_CELLS"] or config["RSZ_CORNERS"] != reference["RSZ_CORNERS"]:
    raise SystemExit("Unexpected alteration to reference cell set or resize corner")
allowed_changes = {"meta", "RUN_POST_GRT_DESIGN_REPAIR"}
if {key for key in config if config.get(key) != reference.get(key)} - allowed_changes:
    raise SystemExit("Unexpected configuration change")

run = root / "asic/runs" / args.tag
evidence = root / "reports/stage13"
evidence.mkdir(parents=True, exist_ok=True)
log_path = evidence / (args.tag + ".log")
manifest_path = evidence / (args.tag + "_manifest.json")
if any(path.exists() for path in (run, log_path, manifest_path)):
    raise SystemExit("Refusing to overwrite prior run/log: " + args.tag)

custom_clock = config["meta"]["flow"] == "Stage12ClockRepair"
if custom_clock:
    pdk_root = Path(os.environ.get("PDK_ROOT", str(Path.home() / ".ciel")))
    command = ["docker", "run", "--rm", "--user", f"{os.getuid()}:{os.getgid()}",
               "-v", f"{root}:{root}", "-v", f"{pdk_root}:{pdk_root}",
               "-e", f"PDK_ROOT={pdk_root}", "-e", "HOME=/tmp", "-w", str(root),
               "ghcr.io/librelane/librelane:3.0.16", "python3",
               "scripts/stage12_clock_flow.py", "--manual-pdk", "--condensed",
               "--hide-progress-bar", "-j", "4", "--run-tag", args.tag,
               str(config_path.relative_to(root))]
else:
    command = [str(root / ".venv-librelane-stage3/bin/python"), "-m", "librelane",
               "--docker-no-tty", "--dockerized", "--manual-pdk", "--condensed",
               "--hide-progress-bar", "-j", "4", "--run-tag", args.tag,
               str(config_path.relative_to(root))]
paths = [root / "sw/game.s", root / "asic/generated/game_rom.v", config_path,
         root / "asic/rom_ram_stage12_no_delay_ss.json", Path(__file__).resolve()]
paths += [(config_path.parent / p.removeprefix("dir::")).resolve()
          for p in config["VERILOG_FILES"]]
if custom_clock:
    paths += [root / "scripts/stage12_clock_flow.py", root / "scripts/stage12_clock_split.tcl"]
paths = list(dict.fromkeys(p.resolve() for p in paths))
manifest = {
    "command": command,
    "inputs_sha256": {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},
}
manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print("Command:", " ".join(command), flush=True)
with log_path.open("w", encoding="utf-8") as log:
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, bufsize=1)
    for line in proc.stdout:
        log.write(line)
        log.flush()
        if any(s in line for s in ("Starting", "ERROR", "WARNING", "completed",
                                    "failed", "success", "Error", "Running")):
            print(line, end="", flush=True)
    code = proc.wait()
    log.write(f"\nSTAGE13_LAUNCHER_RETURN_CODE={code}\n")
print("Return code:", code, "Full log:", log_path, flush=True)
sys.exit(code)
