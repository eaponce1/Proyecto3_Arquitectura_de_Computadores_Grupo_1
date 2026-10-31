#!/bin/sh
set -eu

# The OSS-CAD Verilator executable is a Windows binary. This probe records
# availability and the first compatibility diagnostics without changing RTL.
VERILATOR_BIN="${VERILATOR_BIN:-/mnt/c/Tools/oss-cad-suite/bin/verilator_bin.exe}"
"$VERILATOR_BIN" --version > reports/stage23/verilator_version.log 2>&1 || true
"$VERILATOR_BIN" --lint-only --top-module asic_top_gate \
  reports/entrega/etapa21_combined_gate.nl.v \
  --Wno-fatal > reports/stage23/verilator_gate_lint.log 2>&1 || true
