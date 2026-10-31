#!/bin/sh
set -eu
PDK_ROOT="${PDK_ROOT:-$HOME/.ciel}"
GF180_MODELS="$PDK_ROOT/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog"
SRC="rtl/asic_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v rtl/pochoco_spi_slave.v rtl/pochoco_memory_rom_ram.v rtl/pochoco_memory_unified_ff.v rtl/espino_core/espino_core.v rtl/espino_core/espino_controller.v rtl/espino_core/espino_decoder.v rtl/espino_core/espino_id_stage.v rtl/espino_core/espino_if_stage.v rtl/espino_core/espino_load_store_unit.v rtl/espino_core/espino_register_file.v rtl/espino_core/espino_register_file_ff.v asic/baseline/espino_alu.v asic/generated/game_rom.v"
TB="tests/stage22/stage22_benchmark_tb.v"
mkdir -p tests/stage22 reports/stage22
for mode in rtl gate paired; do
  defs=""
  [ "$mode" = rtl ] && defs="-DRTL_ONLY"
  [ "$mode" = gate ] && defs="-DGATE_ONLY"
  iverilog -g2012 -Wall -DFUNCTIONAL $defs -s stage22_benchmark_tb \
    -o "tests/stage22/stage22_${mode}.vvp" \
    "$GF180_MODELS/primitives.v" "$GF180_MODELS/gf180mcu_fd_sc_mcu7t5v0.v" \
    $SRC reports/entrega/etapa21_combined_gate.nl.v "$TB" \
    2> "reports/stage22/${mode}_compile.log"
  /usr/bin/time -f "elapsed_seconds=%e" -o "reports/stage22/${mode}_time.txt" \
    vvp "tests/stage22/stage22_${mode}.vvp" \
    > "reports/stage22/${mode}_run.log" 2>&1
done
