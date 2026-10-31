#!/bin/sh
set -eu

# Run from the repository root. Override PDK_ROOT if Ciel is elsewhere.
PDK_ROOT="${PDK_ROOT:-$HOME/.ciel}"
GF180_MODELS="$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog"
OUT="tests/stage21/stage21_external.vvp"
LOG="reports/stage21/stage21_external_compare.log"

mkdir -p tests/stage21 reports/stage21
iverilog -g2012 -Wall -DFUNCTIONAL -s stage21_external_tb \
  -o "$OUT" \
  "$GF180_MODELS/primitives.v" \
  "$GF180_MODELS/gf180mcu_fd_sc_mcu7t5v0.v" \
  rtl/asic_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v \
  rtl/pochoco_spi_slave.v rtl/pochoco_memory_rom_ram.v \
  rtl/pochoco_memory_unified_ff.v \
  rtl/espino_core/espino_core.v rtl/espino_core/espino_controller.v \
  rtl/espino_core/espino_decoder.v rtl/espino_core/espino_id_stage.v \
  rtl/espino_core/espino_if_stage.v rtl/espino_core/espino_load_store_unit.v \
  rtl/espino_core/espino_register_file.v rtl/espino_core/espino_register_file_ff.v \
  asic/baseline/espino_alu.v asic/generated/game_rom.v \
  reports/entrega/etapa21_combined_gate.nl.v tests/stage21/stage21_external_tb.v \
  2> reports/stage21/stage21_external_compile.log
vvp "$OUT" > "$LOG" 2>&1
echo "Wrote $LOG"
