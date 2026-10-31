# Proyecto 3 — Etapa 10: optimización arquitectónica localizada

Fecha: 24 de octubre de 2026.

## Resultado ejecutivo

Se evaluó una única modificación: particionar por bytes los muxes de lectura
del register file ASIC. La variante es funcionalmente equivalente y conserva
el número de ciclos, pero **no mejora el cierre eléctrico**. En el peor corner,
slew aumentó de 2695 a 3055 y capacitancia de 10 a 23. Fanout bajó de 58 a 56
según la métrica final de LibreLane, pero su peor carga subió de 18 a 19. La
variante también aumentó área y longitud de cable y redujo el margen de setup.

La configuración reglamentaria `etapa9_rom_ram_util40_debounce` se mantiene
como baseline. El GDS de este experimento no es definitivo.

## Diagnóstico basado en evidencia

La ROM combinacional contiene 143 palabras. Yosys amplía su espacio de
dirección a 256 entradas y antes de optimizar registra en el log 255 muxes de
lectura. Sin embargo, `pochoco_memory_rom_ram` registra `rom_rdata` en
`a_rdata_o`; por ello la lógica de dirección de ROM termina antes de la etapa
secuencial que entrega la instrucción a Espino.

El análisis de
`etapa9_rom_ram_util40_debounce/55-openroad-stapostpnr/max_ss_125C_4v50/checks.rpt`
muestra que las peores redes no son direcciones de la ROM:

- `net385`, `net494` y `net406` se originan en los bits registrados de
  instrucción `[18:15]`, es decir, `rs1`;
- `net453`, `net441` y `net445` se originan en `[23:20]`, es decir, `rs2`;
- en el netlist PNL, por ejemplo, `net385` alimenta muxes de múltiples bits de
  `bank_a[7]`; su driver es un `dlyb_1` insertado sobre un selector compartido;
- 1980 de 2695 violaciones de slew de la baseline fueron clasificadas
  directamente como instrucción/fetch y 103 adicionales mezclan fetch y
  register file;
- las 58 violaciones de fanout de la baseline pertenecen al árbol de reloj;
  dos de sus violaciones de capacitancia también son de CTS.

La causa dominante es, por tanto, la combinación de selectores compartidos de
los dos bancos FF del register file, conos combinacionales posteriores a la
instrucción y CTS. Segmentar la ROM no atacaría las peores redes observadas,
porque están después del registro de salida de memoria.

## Modificación ensayada

Se creó `asic/experimental/espino_register_file_ff_partitioned.v`. Cada copia
de 16 × 32 bits se divide en cuatro memorias de 16 × 8 bits. La intención era
replicar controladamente la decodificación y limitar cada selector a ocho bits
de datos en vez de 32.

La variante mantiene:

- dos puertos de lectura síncrona;
- una copia de almacenamiento por puerto, como la baseline;
- escritura simultánea en ambas copias;
- `x0` constante en cero;
- reset asíncrono activo en bajo;
- exactamente la misma latencia y número de ciclos.

`UsePartitionedRegFile=0` es el valor predeterminado de `asic_top`,
`pochoco_soc` y `espino_core`; por ello la baseline permanece seleccionada si
no se solicita el experimento. La configuración alternativa usa
`UsePartitionedRegFile=1` y está en
`asic/rom_ram_stage10_partitioned.json`. No se cambiaron reloj, utilización,
ROM, RAM, ALU, PDK ni restricciones eléctricas.

## Validación funcional

Comandos ejecutados:

```sh
python3 -B tests/run_tests.py
make stage10-check
make stage10-rtl-compare
```

Resultados:

- 16 pruebas Python: PASS;
- testbenches de core, periféricos, debounce, SPI y decoder: PASS;
- equivalencia ciclo a ciclo del register file baseline/particionado: PASS;
- elaboración de `asic_top` particionado con Icarus: PASS;
- pulsación incorrecta, diez rondas y promedio en la comparación RTL: PASS;
- comparación final: `mismatches=0`, mismo estado observable hasta el ciclo
  10551 del banco acelerado.

La simulación usa la misma ROM en ambas instancias. La corrida física usa
`asic/generated/game_rom.v`, SHA-256
`058209c20fa46c5ebd5639a41180946635320fc47b030d8f78082d651bd5587a`.
`game.s` no fue modificado.

Evidencia: `tests/stage10/evidence/rtl_compare.log` y
`tests/stage10/evidence/rtl_compare.vcd`.

## Síntesis y flujo físico

Comando:

```sh
make stage10-full STAGE10_TAG=etapa10_rom_ram_rf_partitioned
```

Ambas corridas usan LibreLane 3.0.16, `gf180mcuD`, biblioteca
`gf180mcu_fd_sc_mcu7t5v0`, 100 ns y `FP_CORE_UTIL=40`.

| Métrica | Baseline Etapa 9 | Particionado Etapa 10 | Cambio |
|---|---:|---:|---:|
| Área de celdas en síntesis | 139472,032 µm² | 140802,323 µm² | +1330,291 µm² (+0,95 %) |
| Flip-flops | 874 | 874 | 0 |
| Área stdcell final | 181227 µm² | 182676 µm² | +1449 µm² |
| Área de core | 347061 µm² | 351032 µm² | +3971 µm² |
| Área de die | 375554 µm² | 379006 µm² | +3452 µm² |
| Utilización real | 52,2176 % | 52,0396 % | −0,1780 pp |
| Longitud global | 536802 µm | 548394 µm | +11592 µm |
| Longitud route | 392042 µm | 403725 µm | +11683 µm |
| DRC inicial de detailed route, iteración 0 | 140 | 17 | −123 |
| DRC final de routing | 0 | 0 | igual |

La menor cantidad inicial de DRC de routing no implica menor congestión
eléctrica: la variante necesita un die ligeramente mayor, tiene más cable y
termina con más violaciones de transición/capacitancia.

## Timing post-route en nueve corners

Todos los TNS de setup y hold son 0 ns. Los valores mostrados son los peores
slacks no recortados de los reportes finales.

| Corner | Setup baseline | Setup particionado | Hold baseline | Hold particionado |
|---|---:|---:|---:|---:|
| `nom_tt_025C_5v00` | 67,064521 | 63,792699 | 0,369603 | 0,365313 |
| `nom_ss_125C_4v50` | 39,353581 | 34,024830 | 0,927482 | 0,918896 |
| `nom_ff_n40C_5v50` | 72,968030 | 72,833546 | 0,130851 | 0,128221 |
| `min_tt_025C_5v00` | 68,105175 | 65,080679 | 0,362583 | 0,362134 |
| `min_ss_125C_4v50` | 41,176244 | 36,217501 | 0,914839 | 0,913578 |
| `min_ff_n40C_5v50` | 73,188590 | 73,074278 | 0,126038 | 0,125932 |
| `max_tt_025C_5v00` | 65,704969 | 62,256229 | 0,377958 | 0,369185 |
| `max_ss_125C_4v50` | 37,171987 | 31,409535 | 0,941919 | 0,925391 |
| `max_ff_n40C_5v50` | 72,706103 | 72,543303 | 0,136608 | 0,130998 |

La variante cumple timing, pero empeora el peor setup en 5,762452 ns.

## Comparación eléctrica por corner

| Corner | Slew base/nuevo | Cap base/nuevo | Fanout base/nuevo |
|---|---:|---:|---:|
| `nom_tt_025C_5v00` | 53 / 149 | 3 / 4 | 58 / 56 |
| `nom_ss_125C_4v50` | 2094 / 2459 | 3 / 5 | 58 / 56 |
| `nom_ff_n40C_5v50` | 0 / 0 | 3 / 5 | 58 / 56 |
| `min_tt_025C_5v00` | 11 / 11 | 2 / 1 | 58 / 56 |
| `min_ss_125C_4v50` | 1528 / 2020 | 2 / 1 | 58 / 56 |
| `min_ff_n40C_5v50` | 0 / 0 | 2 / 1 | 58 / 56 |
| `max_tt_025C_5v00` | 308 / 312 | 9 / 23 | 58 / 56 |
| `max_ss_125C_4v50` | 2695 / 3055 | 10 / 23 | 58 / 56 |
| `max_ff_n40C_5v50` | 0 / 0 | 9 / 23 | 58 / 56 |

La tabla usa las métricas finales `design__max_*_violation__count` de
LibreLane. El analizador auxiliar logró asociar 55 de las 56 violaciones de
fanout nuevas con redes CTS; el conteo de cierre conservador y autoritativo es
56, no 55.

En `max_ss`, la peor transición pasó de 6,292998 ns a 6,298467 ns para un
límite de 3 ns. La peor capacitancia de clock pasó de 0,337637 a 0,342589 para
un límite de 0,2. El peor fanout de hoja CTS pasó de 18 a 19 para un límite de
10. Aunque el conteo de fanout se redujo en dos, su severidad empeoró.

El análisis de causa de la variante muestra 1688 violaciones directamente en
instrucción/fetch y 695 en conos compartidos de instrucción, datos y
periféricos. Yosys conservó las memorias de byte como listas separadas de
registros, pero el flattening y ABC volvieron a optimizar los conos globales.
La duplicación aumentó área lógica y cableado sin eliminar los selectores
compartidos que OpenROAD reparó con celdas `dlyb_1`.

## Signoff físico observado

| Verificación | Resultado particionado |
|---|---|
| Flujo LibreLane | completo |
| Setup / hold, nueve corners | cumple, TNS 0 |
| Routing DRC | 0 |
| Magic DRC | 0 |
| LVS | 0 |
| Antena post-route | 0 |
| XOR | 0 |
| KLayout DRC externo GF180MCU | limpio |
| Slew / capacitancia / fanout | 3055 / 23 / 56 en el peor conteo |
| Cierre eléctrico | **no cumple** |

KLayout se ejecutó externamente con el mismo deck instalado y sin modificar
reglas:

```sh
make stage10-klayout-drc \
  STAGE10_TAG=etapa10_rom_ram_rf_partitioned \
  STAGE10_KLAYOUT_DIR=reports/stage10/klayout_drc_partitioned
```

El log termina con `Klayout DRC run is clean. GDS has no DRC violations.`

## Evidencias

- baseline: `asic/runs/etapa9_rom_ram_util40_debounce/`;
- experimento: `asic/runs/etapa10_rom_ram_rf_partitioned/`;
- configuración: `asic/rom_ram_stage10_partitioned.json`;
- RTL alternativo: `asic/experimental/espino_register_file_ff_partitioned.v`;
- diagnóstico eléctrico: `reports/stage10/electrical_partitioned.{json,csv}`;
- KLayout: `reports/stage10/klayout_drc_partitioned/`;
- simulación: `tests/stage10/evidence/`;
- síntesis: `06-yosys-synthesis/yosys-synthesis.log` de cada corrida;
- STA: `55-openroad-stapostpnr/<corner>/checks.rpt` y `metrics.json`.

## Recomendación final

Descartar el register file particionado como candidato físico y conservar la
baseline reglamentaria. El experimento demuestra que reducir el fanout lógico
aparente de un selector no basta: la optimización global, el cableado y CTS
dominan el resultado post-route.

Una siguiente intervención solo sería justificable si se dirige por separado
al árbol de reloj y a los drivers concretos `dlyb_1` después de estudiar las
opciones de CTS/resizer admitidas por LibreLane. No debe combinarse con esta
partición ni declararse GDS definitivo mientras queden violaciones.
