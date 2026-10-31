# Proyecto 3 — Etapa 4: timing y camino crítico

## Alcance y entorno

Se usó LibreLane 3.0.16, flujo `Classic` detenido en `OpenROAD.STAPostPNR` (después de routing detallado, fill y extracción RC; **sin signoff final ni GDSII**), PDK `gf180mcuD` revisión `8afc8346a57fe1ab7934ba5a6056ea8b43078e71` (`open_pdks`) y biblioteca `gf180mcu_fd_sc_mcu7t5v0`. El puerto de reloj es `clk_i`. Todas las corridas mantienen `FP_CORE_UTIL=40` y usan 100 ns salvo los overrides indicados. LibreLane evaluó `nom`, `min` y `max` para TT 25 °C/5,00 V, SS 125 °C/4,50 V y FF −40 °C/5,50 V. Se usó la SDC genérica de LibreLane; faltan restricciones de interfaz ASIC específicas.

Las corridas de síntesis de Etapa 3 permanecen en `asic/runs/etapa3_rom_ram_v2` y `asic/runs/etapa3_unified_ff_v2`. Las corridas de esta etapa se guardan en directorios nuevos; ninguna fue sobrescrita. Los originales de FPGA (`sw/game.s`, `sw/game.hex`, `rtl/game_rom.v` y `rtl/espino_core/espino_alu.v`) se conservan.

## Programa ASIC a 100 ns

`T = 100 ns` implica `f = 1/T = 10 MHz`. Para tres segundos: `3 s × 10 000 000 ciclos/s = 30 000 000 = 0x01C9C380`, cargado por `lui x2,0x1C9C` y `addi x2,x2,896`. Para una décima: `0,1 s × 10 000 000 = 1 000 000 = 0x000F4240`, cargado por `lui x3,0xF4` y `addi x3,x3,576`. La imagen FPGA usa 75 000 000 y 2 500 000 respectivamente. `sw/game_asic_100ns.s` es una copia de la lógica del juego con solo esas constantes y comentarios dependientes del reloj modificados. Ambas imágenes tienen 143 instrucciones; la comparación binaria difiere solo en las posiciones 2–5. Las diez rondas permanecen intactas. El timeout basado en `2^31` ciclos permanece igual en ciclos, por lo que su tiempo real pasa de ~85,9 s a ~214,75 s.

Regeneración reproducible: `make asic-rom-100ns` (equivale a `python3 sw/assembler.py sw/game_asic_100ns.s -o asic/generated/game_100ns.hex --verilog-rom asic/generated/game_rom.v`). La configuración FPGA original sigue usando `sw/game.s` y `rtl/game_rom.v`.

## Configuraciones y comandos

`asic/rom_ram_100ns.json` y `asic/unified_ff_100ns.json` usan la imagen ASIC y la ALU baseline congelada en `asic/baseline/espino_alu.v`. `asic/rom_ram_100ns_opt.json` usa `asic/optimized/espino_alu.v`; esta variante no entra en el wildcard de fuentes FPGA. Los dos JSON de Etapa 3 no se modificaron.

Desde WSL, con el bind mount `/tmp/pochoco3` para evitar el espacio en la ruta de Windows:

```sh
cd /tmp/pochoco3
make asic-rom-100ns asic-stage4-check asic-stage4-check-opt
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_100 --to OpenROAD.STAPostPNR asic/rom_ram_100ns.json
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_70 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=70 asic/rom_ram_100ns.json
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_62 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=62 asic/rom_ram_100ns.json
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_100ns_60 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=60 asic/rom_ram_100ns.json
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_rom_ram_opt_60 --to OpenROAD.STAPostPNR -c CLOCK_PERIOD=60 asic/rom_ram_100ns_opt.json
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized --manual-pdk --condensed --hide-progress-bar -j 4 --run-tag etapa4_unified_ff_100ns_100 --to OpenROAD.STAPostPNR asic/unified_ff_100ns.json
```

Los targets equivalentes están en `Makefile`. Cada corrida debe tener una etiqueta nueva al repetirse: no usar `--overwrite` sobre los reportes originales.

Archivos creados en esta etapa: `sw/game_asic_100ns.s`, `asic/generated/game_100ns.hex`, `asic/generated/game_rom.v`, los tres JSON `asic/*_100ns*.json`, `asic/baseline/espino_alu.v`, `asic/optimized/espino_alu.v`, `tests/alu_stage4_tb.v` y este documento. Se modificaron `Makefile`, `tests/test_game.py` y `tests/test_asic_memory.py` para regeneración y pruebas. El assembler y los fuentes FPGA no se alteraron. Los directorios `asic/runs/etapa4_*` contienen los resultados originales de las corridas; no se borraron los de Etapa 3.

## Timing post-route

WNS/TNS provienen del `55-openroad-stapostpnr/state_out.json` de cada corrida, no de Yosys ni de STA pre-placement. LibreLane reporta WNS = 0 cuando el peor slack es positivo; por eso se incluye también `WS`, el peor slack real del reporte. Todas las cifras están en ns salvo TNS, también en ns sumados. La validez exige WNS ≥ 0 y TNS = 0 de setup y hold en **todos** los corners. Las métricas de los nueve corners están en el `state_out.json` original de cada corrida.

| Arquitectura / período | Corner | Setup WNS | Setup TNS | Setup WS | Hold WNS | Hold TNS | Hold WS |
|---|---|---:|---:|---:|---:|---:|---:|
| ROM+RAM base / 100 ns | nom_tt_025C_5v00 | 0 | 0 | 67,579 | 0 | 0 | 0,385 |
| ROM+RAM base / 100 ns | max_ss_125C_4v50 | 0 | 0 | 38,023 | 0 | 0 | 0,965 |
| ROM+RAM base / 100 ns | min_ff_n40C_5v50 | 0 | 0 | 72,403 | 0 | 0 | 0,137 |
| ROM+RAM base / 70 ns | nom_tt_025C_5v00 | 0 | 0 | 37,579 | 0 | 0 | 0,385 |
| ROM+RAM base / 70 ns | max_ss_125C_4v50 | 0 | 0 | 8,023 | 0 | 0 | 0,965 |
| ROM+RAM base / 70 ns | min_ff_n40C_5v50 | 0 | 0 | 48,403 | 0 | 0 | 0,137 |
| ROM+RAM base / 62 ns | nom_tt_025C_5v00 | 0 | 0 | 29,579 | 0 | 0 | 0,385 |
| ROM+RAM base / 62 ns | max_ss_125C_4v50 | 0 | 0 | 0,023 | 0 | 0 | 0,965 |
| ROM+RAM base / 62 ns | min_ff_n40C_5v50 | 0 | 0 | 42,003 | 0 | 0 | 0,137 |
| ROM+RAM base / 60 ns | nom_tt_025C_5v00 | 0 | 0 | 27,579 | 0 | 0 | 0,385 |
| ROM+RAM base / 60 ns | max_ss_125C_4v50 | −1,977 | −26,791 | −1,977 | 0 | 0 | 0,965 |
| ROM+RAM base / 60 ns | min_ff_n40C_5v50 | 0 | 0 | 40,355 | 0 | 0 | 0,137 |
| ROM+RAM optimizada / 60 ns | nom_tt_025C_5v00 | 0 | 0 | 24,604 | 0 | 0 | 0,403 |
| ROM+RAM optimizada / 60 ns | nom_ss_125C_4v50 | −4,839 | −111,410 | −4,839 | 0 | 0 | 0,998 |
| ROM+RAM optimizada / 60 ns | max_ss_125C_4v50 | −7,069 | −264,994 | −7,069 | 0 | 0 | 1,001 |
| ROM+RAM optimizada / 60 ns | min_ff_n40C_5v50 | 0 | 0 | 38,444 | 0 | 0 | 0,150 |
| Unificada / 100 ns, imagen ASIC | nom_tt_025C_5v00 | 0 | 0 | 60,252 | 0 | 0 | 0,437 |
| Unificada / 100 ns, imagen ASIC | max_ss_125C_4v50 | 0 | 0 | 23,747 | 0 | 0 | 1,061 |
| Unificada / 100 ns, imagen ASIC | min_ff_n40C_5v50 | 0 | 0 | 68,505 | 0 | 0 | 0,172 |
| Unificada / 100 ns, imagen FPGA | nom_tt_025C_5v00 | 0 | 0 | 57,932 | 0 | 0 | 0,382 |
| Unificada / 100 ns, imagen FPGA | max_ss_125C_4v50 | 0 | 0 | 23,561 | 0 | 0 | 0,959 |
| Unificada / 100 ns, imagen FPGA | min_ff_n40C_5v50 | 0 | 0 | 66,663 | 0 | 0 | 0,136 |

La corrida baseline de 60 ns llegó a STA post-route sin error de flujo, pero **no cumple setup** en `max_ss_125C_4v50`. Las de 100, 70 y 62 ns sí cumplen setup y hold en los nueve corners; se verificó que ninguna de las 36 métricas WNS/TNS por corrida es negativa. El menor período **demostrado** es **62 ns**, es decir `f = 1/(62 ns) = 16,129032 MHz`; 60 ns falla. El margen de 62 ns es estrecho (0,023 ns), y esta frecuencia no es signoff. La variante optimizada falla en los corners SS `nom`, `min` y `max`. La unificada con imagen ASIC también cumple setup y hold en los nueve corners a 100 ns; las filas con imagen FPGA son una referencia física anterior al ajuste de constantes.

La calibración temporal del juego corresponde a 100 ns. Si se operara realmente a 62 ns, las mismas constantes producirían esperas de 1,86 s y unidades de respuesta de 0,062 s; el barrido a 62 ns solo demuestra margen físico, no conserva por sí mismo la escala de tiempo prevista.

## Área, utilización y ruta crítica

| ROM+RAM baseline | Área celdas después de placement | Utilización después de placement | Área estándar post-route, sin fillers | Utilización post-route |
|---|---:|---:|---:|---:|
| 100/70/62/60 ns baseline | 153 524 µm² | 43,243 % | 184 179 µm² | 51,878 % |
| 60 ns optimizada | 155 010 µm² | 43,457 % | 186 348 µm² | 52,243 % |
| 100 ns unificada, imagen ASIC | 609 398 µm² | 43,115 % | 730 205 µm² | 51,662 % |
| 100 ns unificada, imagen FPGA | 608 586 µm² | 43,098 % | 724 232 µm² | 51,287 % |

`design__instance__area` total post-route incluye aproximadamente 170 846 µm² de fillers y no debe compararse directamente con el área de celdas de placement; la métrica comparable es `design__instance__area__stdcell`. El área de síntesis Yosys para esta imagen ASIC baseline fue 142 038,2208 µm².

En 100 ns y `max_ss_125C_4v50`, el reporte `asic/runs/etapa4_rom_ram_100ns_100/55-openroad-stapostpnr/max_ss_125C_4v50/max.rpt` identifica inicio `_8522_` (`u_pochoco_soc.genblk1.g_rom_ram_memory.u_ram.a_rdata_o[3]`) y destino `_8510_` (`u_pochoco_soc.genblk1.g_rom_ram_memory.u_ram.a_addr_i[25]`, bit del PC). Es un camino de **fetch → decode/ejecución de salto → actualización de PC** dentro de Espino. La llegada es 63,886 ns, el tiempo requerido 101,909 ns y el slack 38,023 ns. La red atraviesa varias etapas de decode, comparación/control y buffers de alto fanout; el detalle celda por celda está en el `max.rpt`. El mapeo de `_8522_` y `_8510_` se verificó en `06-yosys-synthesis/asic_top.nl.v`.

Para la unificada ASIC a 100 ns, `asic/runs/etapa4_unified_ff_100ns_100/55-openroad-stapostpnr/max_ss_125C_4v50/max.rpt` identifica inicio `_24677_` (`u_ram.a_rdata_o[4]`) y destino `_29578_` (`u_core.g_asic_regfile.u_rf.bank_a[12][16]`): **lectura de memoria → selección de dato → write-back**. La llegada es 80,156 ns, el tiempo requerido 103,903 ns y el slack 23,747 ns; la ruta incluye buffers de alto fanout y lógica combinacional de selección. El mapeo se verificó en su netlist `06-yosys-synthesis/asic_top.nl.v`.

## Experimento RTL y verificaciones

La ALU baseline permanece en `rtl/espino_core/espino_alu.v` y está copiada funcionalmente en `asic/baseline/espino_alu.v`. La variante `asic/optimized/espino_alu.v` calcula `==`, `<` signed y `<` unsigned directamente, en paralelo con el sumador/restador; el selector de branch recibe comparaciones ya calculadas. Era una hipótesis de reducción de la dependencia entre opcode y carry chain, a costa de lógica adicional. No cambia el RTL FPGA.

**Resultado negativo a 60 ns:** el WNS setup en `max_ss_125C_4v50` pasó de −1,977 a −7,069 ns (empeoró 5,092 ns), y el TNS de −26,791 a −264,994 ns. El área de celdas después de placement creció 1486 µm² (+0,968 %); el área estándar post-route creció 2169 µm² (+1,178 %). Hold siguió cumpliendo. El camino crítico optimizado, respaldado por `asic/runs/etapa4_rom_ram_opt_60/55-openroad-stapostpnr/max_ss_125C_4v50/max.rpt`, parte de `_8873_` (`u_ram.a_rdata_o[2]`) y termina en `_8881_` (`u_ram.a_rdata_o[10]`): decode/control, selección de siguiente PC y fetch de la siguiente instrucción aún forman una ruta larga. El cambio desplazó la ruta crítica al ciclo de fetch y añadió carga/área, sin lograr una mejora global. La variante queda conservada como experimento, **no seleccionada**.

Comprobaciones realizadas: `python3 -B tests/run_tests.py` pasó 16 pruebas Python y las simulaciones RTL de core, periféricos, SPI y decoder; el test ASIC de diez rondas/rom de 100 ns está incluido. `asic_game_smoke_tb.v` pasó para ambas memorias con la nueva ROM y para ROM+RAM con la ALU optimizada. `tests/alu_stage4_tb.v` pasó 16 000 combinaciones aleatorias/códigos de operación para ambas ALU; `make asic-stage4-check` y `make asic-stage4-check-opt` pasaron con Icarus. Estas pruebas no reemplazan la verificación post-síntesis ni una simulación RTL de toda la partida a duración física real.

## Logs y límites

Para cada etiqueta `N` de `asic/runs/N`, conservar: `flow.log`, `warning.log`, `error.log`, `28-openroad-globalplacement/state_out.json`, `44-openroad-detailedrouting/openroad-detailedrouting.log` y `55-openroad-stapostpnr/state_out.json` junto con sus subdirectorios de corner (`max.rpt`, `min.rpt`, `wns.*.rpt`, `tns.*.rpt`). Las corridas `etapa4_baseline_rom_ram_100` y `etapa4_baseline_unified_ff_100` usan aún la imagen FPGA de 25 MHz; ambas cerraron post-route a 100 ns y se conservan como referencias previas al ajuste de constantes. `etapa4_rom_ram_100ns_100`, `_70`, `_62` y `_60` son el barrido baseline; `etapa4_rom_ram_opt_60` es la variante descartada por timing; `etapa4_unified_ff_100ns_100` es la unificada con imagen ASIC. Todas alcanzaron `OpenROAD.STAPostPNR`; las corridas a 60 ns completaron el flujo, aunque fallaron los criterios de setup.

Warnings no fatales observados: 16 de lint, SDC genérica por ausencia de `PNR_SDC_FILE`/`SIGNOFF_SDC_FILE`, `[STA-1140]` bibliotecas ya cargadas, `[RSZ-0020]` dos redes flotantes y `[DRT-0349]` ciertas reglas LEF58 de enclosure omitidas. Ambas corridas unificadas emitieron `[GRT-0243] Unable to repair antennas on net with diodes`; en la imagen ASIC `route__drc_errors=0`, pero `route__antenna_violation__count=1`. En `max_ss`, también quedan 9734 violaciones de max slew, 350 de max fanout y 949 de max capacitance; ROM+RAM baseline conserva 3008, 56 y 31 respectivamente. Deben resolverse o justificarse antes de signoff: pasar WNS/TNS no basta. No se ejecutaron DRC/LVS finales, IR drop ni GDSII. El timing se limita a la SDC genérica y a los corners proporcionados por este PDK/flujo. No se ha optimizado floorplan ni se ha hecho signoff.
