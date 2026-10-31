# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# you may not use this file except in compliance with the License.
# SPDX-License-Identifier: SHL-0.51
#
# Course: Arquitectura de Computadores (2026)
# 
# Authors:
# - Nicolás Villegas <navillegas@miuandes.cl>

# Configuration
TOP  := game_top
PCF  := goboard.pcf

# RTL Sources
SRC  := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# Build Targets
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin

.PHONY: all prog clean test asic-rom asic-check asic-synth-rom-ram asic-synth-unified-ff asic-full-rom-ram asic-full-unified-ff asic-rom-100ns asic-stage4-check asic-stage4-check-opt asic-stage4-rom-100 asic-stage4-rom-70 asic-stage4-rom-62 asic-stage4-rom-60 asic-stage4-rom-opt-60 asic-stage4-unified-100 asic-stage5-util30 asic-stage5-util40 asic-stage5-util50 asic-stage5-util50-repair asic-stage5-util50-fanout4 asic-stage5-util40-fanout4 asic-stage5-util50-buf4 stage7-program stage7-synth stage7-netlist stage7-compile stage7-run stage9-regulatory stage9-klayout-drc stage10-check stage10-rtl-compare stage10-full stage10-klayout-drc

# Run these targets inside WSL after installing LibreLane and a GF180MCU PDK.
LIBRELANE ?= .venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk
ASIC_PYTHON ?= python3
ASIC_RTL := rtl/asic_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v rtl/pochoco_spi_slave.v rtl/pochoco_memory_rom_ram.v rtl/pochoco_memory_unified_ff.v rtl/game_rom.v $(filter-out rtl/espino_core/espino_register_file.v,$(wildcard rtl/espino_core/*.v))
ASIC_STAGE4_RTL := $(filter-out rtl/game_rom.v rtl/espino_core/espino_alu.v,$(ASIC_RTL)) asic/generated/game_rom.v asic/baseline/espino_alu.v
ASIC_STAGE4_OPT_RTL := $(filter-out rtl/game_rom.v rtl/espino_core/espino_alu.v,$(ASIC_RTL)) asic/generated/game_rom.v asic/optimized/espino_alu.v

asic/generated/game_rom.v asic/generated/game_100ns.hex &: sw/game_asic_100ns.s sw/assembler.py
	mkdir -p asic/generated
	$(ASIC_PYTHON) sw/assembler.py sw/game_asic_100ns.s -o asic/generated/game_100ns.hex --verilog-rom asic/generated/game_rom.v

asic-rom-100ns: asic/generated/game_rom.v asic/generated/game_100ns.hex

asic-stage4-check: asic-rom-100ns
	iverilog -g2012 -Wall -s asic_top -o /tmp/pochoco_stage4_rom.vvp $(ASIC_STAGE4_RTL)
	iverilog -g2012 -Wall -s asic_top -Pasic_top.MemoryArchitecture=2 -o /tmp/pochoco_stage4_unified.vvp $(ASIC_STAGE4_RTL)

asic-stage4-check-opt: asic-rom-100ns
	iverilog -g2012 -Wall -s asic_top -o /tmp/pochoco_stage4_opt.vvp $(ASIC_STAGE4_OPT_RTL)

asic-stage4-rom-100: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_100 --to OpenROAD.STAPostPNR asic/rom_ram_100ns.json

asic-stage4-rom-70: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_70 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=70 asic/rom_ram_100ns.json

asic-stage4-rom-62: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_62 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=62 asic/rom_ram_100ns.json

asic-stage4-rom-60: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_60 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=60 asic/rom_ram_100ns.json

asic-stage4-rom-opt-60: asic-stage4-check-opt
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_opt_60 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=60 asic/rom_ram_100ns_opt.json

asic-stage4-unified-100: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa4_unified_ff_100ns_100 --to OpenROAD.STAPostPNR asic/unified_ff_100ns.json

asic-stage5-util30: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util30 asic/rom_ram_util30.json

asic-stage5-util40: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util40 asic/rom_ram_util40.json

asic-stage5-util50: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util50 asic/rom_ram_util50.json

asic-stage5-util50-repair: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util50_repair asic/rom_ram_util50_repair.json

asic-stage5-util50-fanout4: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util50_fanout4 asic/rom_ram_util50_fanout4.json

asic-stage5-util40-fanout4: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util40_fanout4 asic/rom_ram_util40_fanout4.json

asic-stage5-util50-buf4: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag etapa5_rom_ram_util50_buf4 asic/rom_ram_util50_buf4.json

# Mandatory delivery reference: ROM+RAM, 100 ns, FP_CORE_UTIL=40.  The tag is
# overrideable so a reproduction never needs to overwrite an earlier run.
ETAPA9_TAG ?= etapa9_rom_ram_util40_debounce
stage9-regulatory: asic-stage4-check
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(ETAPA9_TAG) asic/rom_ram_util40.json

STAGE9_GDS ?= asic/runs/$(ETAPA9_TAG)/final/gds/asic_top.gds
STAGE9_KLAYOUT_DIR ?= reports/stage9/klayout_drc_repro
stage9-klayout-drc:
	sh scripts/run_klayout_drc.sh "$(STAGE9_GDS)" "$(STAGE9_KLAYOUT_DIR)"

# Stage 10: one-variable experiment.  Only the ASIC register-file read muxes
# are partitioned; clock, utilization, ROM/RAM and all flow settings remain at
# the mandatory 100 ns / 40 % baseline values.
STAGE10_TAG ?= etapa10_rom_ram_rf_partitioned
STAGE10_RTL := $(filter-out rtl/game_rom.v rtl/espino_core/espino_alu.v,$(ASIC_RTL)) \
	asic/generated/game_rom.v asic/baseline/espino_alu.v \
	asic/experimental/espino_register_file_ff_partitioned.v
STAGE10_SIM_RTL := $(filter-out rtl/game_rom.v rtl/espino_core/espino_alu.v,$(ASIC_RTL)) \
	tests/stage7/generated/game_rom.v asic/baseline/espino_alu.v \
	asic/experimental/espino_register_file_ff_partitioned.v

stage10-check: asic-rom-100ns
	iverilog -g2012 -Wall -s asic_top -Pasic_top.UsePartitionedRegFile=1 \
		-o /tmp/pochoco_stage10_partitioned.vvp $(STAGE10_RTL)

stage10-rtl-compare: stage7-program
	mkdir -p tests/stage10/evidence
	iverilog -g2012 -Wall -s stage10_rtl_compare_tb \
		-o tests/stage10/evidence/stage10_rtl_compare.vvp \
		$(STAGE10_SIM_RTL) tests/stage10/stage10_rtl_compare_tb.v
	vvp tests/stage10/evidence/stage10_rtl_compare.vvp \
		> tests/stage10/evidence/rtl_compare.log 2>&1

stage10-full: stage10-check stage10-rtl-compare
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(STAGE10_TAG) \
		asic/rom_ram_stage10_partitioned.json

STAGE10_GDS ?= asic/runs/$(STAGE10_TAG)/final/gds/asic_top.gds
STAGE10_KLAYOUT_DIR ?= reports/stage10/klayout_drc
stage10-klayout-drc:
	sh scripts/run_klayout_drc.sh "$(STAGE10_GDS)" "$(STAGE10_KLAYOUT_DIR)"

.PHONY: etapa6-cts etapa6-grt60 etapa6-grt80 etapa6-layout
ETAPA6_CTS_TAG ?= etapa6_rom_ram_cts_next
ETAPA6_GRT60_TAG ?= etapa6_rom_ram_grt60_next
ETAPA6_GRT80_TAG ?= etapa6_rom_ram_grt80_next
etapa6-cts:
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(ETAPA6_CTS_TAG) asic/rom_ram_etapa6_cts.json

etapa6-grt60:
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(ETAPA6_GRT60_TAG) asic/rom_ram_etapa6_grt60.json

etapa6-grt80:
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(ETAPA6_GRT80_TAG) asic/rom_ram_etapa6_grt80.json

etapa6-layout:
	$(ASIC_PYTHON) scripts/annotate_layout.py asic/runs/etapa6_rom_ram_grt60 \
		docs/figures/etapa6_layout_trazabilidad.svg \
		--csv docs/figures/etapa6_trazabilidad.csv

# Stage 7: zero-delay post-synthesis functional co-simulation.
# Override PDK_ROOT if Ciel is installed elsewhere.
PDK_ROOT ?= $(HOME)/.ciel
GF180_MODELS := $(PDK_ROOT)/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog
ETAPA7_TAG ?= etapa7_rom_ram_post_synth_repro
STAGE7_RTL := rtl/asic_top.v rtl/pochoco_soc.v rtl/pochoco_periph.v \
	rtl/pochoco_spi_slave.v rtl/pochoco_memory_rom_ram.v \
	rtl/pochoco_memory_unified_ff.v \
	rtl/espino_core/espino_core.v rtl/espino_core/espino_controller.v \
	rtl/espino_core/espino_decoder.v rtl/espino_core/espino_id_stage.v \
	rtl/espino_core/espino_if_stage.v rtl/espino_core/espino_load_store_unit.v \
	rtl/espino_core/espino_register_file.v rtl/espino_core/espino_register_file_ff.v \
	asic/baseline/espino_alu.v tests/stage7/generated/game_rom.v

stage7-program:
	$(ASIC_PYTHON) tests/stage7/prepare_program.py
	$(ASIC_PYTHON) sw/assembler.py tests/stage7/generated/game_stage7.s \
		-o tests/stage7/generated/game_stage7.hex \
		--verilog-rom tests/stage7/generated/game_rom.v

stage7-synth: stage7-program
	$(LIBRELANE) --condensed --hide-progress-bar -j 4 --run-tag $(ETAPA7_TAG) \
		--to Yosys.Synthesis asic/rom_ram_stage7_sim.json

stage7-netlist:
	$(ASIC_PYTHON) tests/stage7/prepare_netlist.py \
		--source asic/runs/$(ETAPA7_TAG)/06-yosys-synthesis/asic_top.nl.v

stage7-compile: stage7-program stage7-netlist
	mkdir -p tests/stage7/evidence
	iverilog -g2012 -Wall -DFUNCTIONAL -s stage7_tb \
		-o tests/stage7/generated/stage7.vvp \
		$(GF180_MODELS)/primitives.v \
		$(GF180_MODELS)/gf180mcu_fd_sc_mcu7t5v0.v \
		$(STAGE7_RTL) tests/stage7/generated/asic_top_gate.nl.v \
		tests/stage7/stage7_tb.v 2> tests/stage7/evidence/compile.log

stage7-run: stage7-compile
	vvp tests/stage7/generated/stage7.vvp > tests/stage7/evidence/rtl.log 2>&1
	vvp tests/stage7/generated/stage7.vvp +GATE_VCD > tests/stage7/evidence/post_synth.log 2>&1
	$(ASIC_PYTHON) tests/stage7/compare_logs.py \
		tests/stage7/evidence/rtl.log tests/stage7/evidence/post_synth.log \
		--output tests/stage7/evidence/comparison.txt

asic-check: asic-rom
	iverilog -g2012 -Wall -s asic_top -o /tmp/pochoco_asic_rom_ram.vvp $(ASIC_RTL)
	iverilog -g2012 -Wall -s asic_top -Pasic_top.MemoryArchitecture=2 -o /tmp/pochoco_asic_unified_ff.vvp $(ASIC_RTL)

ROM_RAM_SYNTH_TAG ?= etapa3_rom_ram_repro
UNIFIED_SYNTH_TAG ?= etapa3_unified_ff_repro
ROM_RAM_FULL_TAG ?= etapa3_full_rom_ram_repro
UNIFIED_FULL_TAG ?= etapa3_full_unified_ff_repro

asic-synth-rom-ram: asic-check
	$(LIBRELANE) --run-tag $(ROM_RAM_SYNTH_TAG) --to yosys.synthesis asic/rom_ram.json

asic-synth-unified-ff: asic-check
	$(LIBRELANE) --run-tag $(UNIFIED_SYNTH_TAG) --to yosys.synthesis asic/unified_ff.json

asic-full-rom-ram: asic-check
	$(LIBRELANE) --run-tag $(ROM_RAM_FULL_TAG) asic/rom_ram.json

asic-full-unified-ff: asic-check
	$(LIBRELANE) --run-tag $(UNIFIED_FULL_TAG) asic/unified_ff.json

# Default target
all: $(BIN)

PYTHON ?= python3

rtl/game_rom.v sw/game.hex &: sw/game.s sw/assembler.py
	$(PYTHON) sw/assembler.py sw/game.s -o sw/game.hex --verilog-rom rtl/game_rom.v

asic-rom: rtl/game_rom.v sw/game.hex

# Step 1: Synthesis using Yosys
$(JSON): $(SRC) sw/game.hex rtl/game_rom.v Makefile
	yosys -p "read_verilog $(SRC); scratchpad -set abc9.xaiger 1; synth_ice40 -top $(TOP) -json ${TOP}.json"

# Step 2: Place and Route using NextPNR
$(ASC): $(JSON) $(PCF) Makefile
	nextpnr-ice40 --freq 25 --hx1k --package vq100 --json $(JSON) --pcf $(PCF) --asc $(ASC)

# Step 3: Bitstream Generation
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)

# Step 4: Flash the Board
prog: $(BIN)
	iceprog $(BIN)

# Clean up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN)

# Regression tests (Python + Icarus Verilog)
test:
	$(PYTHON) -B tests/run_tests.py
