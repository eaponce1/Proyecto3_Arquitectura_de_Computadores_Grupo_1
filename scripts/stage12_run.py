#!/usr/bin/env python3
"""Run an isolated full LibreLane candidate; never overwrite an earlier run."""
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
if not args.tag.startswith("etapa12_") or "/" in args.tag:
    raise SystemExit("Expected a simple etapa12_ run tag")
os.chdir(root)
run = root / "asic/runs" / args.tag
evidence = root / "reports/stage12"
evidence.mkdir(parents=True, exist_ok=True)
log_path = evidence / (args.tag + ".log")
if run.exists() or log_path.exists():
    raise SystemExit("Refusing to overwrite run/log: " + args.tag)
cfg = json.loads(Path(args.config).read_text())
assert cfg["CLOCK_PERIOD"] == 100 and cfg["FP_CORE_UTIL"] == 40
assert cfg["STD_CELL_LIBRARY"] == "gf180mcu_fd_sc_mcu7t5v0"
assert cfg["SYNTH_PARAMETERS"] == ["MemoryArchitecture=1"]
for key in ("MAX_TRANSITION_CONSTRAINT", "MAX_CAPACITANCE_CONSTRAINT", "MAX_FANOUT_CONSTRAINT"):
    assert key not in cfg, key
command = [str(root / ".venv-librelane-stage3/bin/python"), "-m", "librelane",
           "--docker-no-tty", "--dockerized", "--manual-pdk",
           "--condensed", "--hide-progress-bar", "-j", "4",
           "--run-tag", args.tag, args.config]
if cfg["meta"]["flow"] == "Stage12ClockRepair":
    pdk_root = Path(os.environ.get("PDK_ROOT", str(Path.home() / ".ciel")))
    command = ["docker", "run", "--rm",
               "--user", str(os.getuid()) + ":" + str(os.getgid()),
               "-v", str(root) + ":" + str(root),
               "-v", str(pdk_root) + ":" + str(pdk_root),
               "-e", "PDK_ROOT=" + str(pdk_root), "-e", "HOME=/tmp",
               "-w", str(root), "ghcr.io/librelane/librelane:3.0.16",
               "python3", "scripts/stage12_clock_flow.py",
               "--manual-pdk", "--condensed", "--hide-progress-bar",
               "-j", "4", "--run-tag", args.tag, args.config]
paths = [root / "sw/game.s", root / "asic/generated/game_rom.v",
         root / "asic/rom_ram_util40.json", root / args.config]
paths += [(root / args.config).parent / p.removeprefix("dir::")
          for p in cfg["VERILOG_FILES"]]
paths += [Path(__file__).resolve()]
if cfg["meta"]["flow"] == "Stage12ClockRepair":
    paths += [root / "scripts/stage12_clock_flow.py",
              root / "scripts/stage12_clock_split.tcl"]
paths = list(dict.fromkeys(p.resolve() for p in paths))
manifest = dict(command=command, inputs_sha256={str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
(evidence / (args.tag + "_manifest.json")).write_text(json.dumps(manifest, indent=2))
print("Command: " + " ".join(command), flush=True)
with log_path.open("w", encoding="utf-8") as log:
    proc = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    for line in proc.stdout:
        log.write(line)
        log.flush()
        if any(s in line for s in ("Starting", "ERROR", "WARNING", "completed", "failed", "success", "Error", "Running")):
            print(line, end="", flush=True)
    rc = proc.wait()
    log.write("\nSTAGE12_LAUNCHER_RETURN_CODE=" + str(rc) + "\n")
print("Return code:", rc, "Full log:", log_path, flush=True)
sys.exit(rc)

