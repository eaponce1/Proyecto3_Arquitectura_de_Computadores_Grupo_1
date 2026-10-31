# Proyecto 3 — Etapa 19: reparación de drivers y verificación integral

## Punto de partida y diagnóstico

Se partió del estado detalladamente ruteado de `etapa18_group4`, sin modificar RTL, Assembly ni la imagen de memoria. El STA post-route con SPEF reportó 127 pines infractores, 150 apariciones y 31 redes físicas, concentradas en los corners SS (`max_ss_125C_4v50`, `min_ss_125C_4v50` y `nom_ss_125C_4v50`). Las redes principales fueron la salida de dirección de RAM `u_ram.a_addr_i[9]` (driver `_8442_/Q`, 10 apariciones), `_1397_` (driver `_4782_/ZN`, 8), `data_wdata[2]` (driver `_9247_/Q`, 8), `_2349_` (driver `_5849_/ZN`, 8) y `data_wdata[3]` (driver `_9248_/Q`, 8). También persistieron conos de instrucción con drivers `aoi221`, `aoi211`, `nand2` y buffers `buf_1`.

El análisis agrupado está en `reports/stage19/group1/`, `group2/` y `group3/`. El problema seguía distribuido en numerosas redes de instrucción/ROM, register file y datos; no era una única red dominante. Las redes ya intervenidas en las etapas 15–18 se excluyeron de la selección inicial para evitar ECO redundantes.

## Biblioteca y estrategia

La revisión instalada contiene `gf180mcu_fd_sc_mcu7t5v0__buf_1`, `__buf_2`, `__buf_4`, `__buf_8`, `__buf_12`, `__buf_16` y `__buf_20` en los archivos de la biblioteca estándar. Se verificó la existencia física de `__buf_4` en la revisión GF180MCU instalada antes de usarla. Las sustituciones ECO utilizaron únicamente `gf180mcu_fd_sc_mcu7t5v0__buf_4`, manteniendo la conectividad lógica y los pines del buffer. No se modificaron límites Liberty ni restricciones SDC.

## Experimentos post-route

Cada grupo se ejecutó desde el `state_out.json` detalladamente ruteado del grupo anterior. LibreLane 3.0.16 ejecutó legalización, rerouting, RCX para `nom`, `min` y `max`, STA post-route en nueve corners y los verificadores físicos.

| Estado | Drivers ECO | Slew | Cap. | Fanout | Área stdcell | Utilización | Setup mínimo (ns) | Hold mínimo (ns) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Etapa 18 group4 | referencia | 127 | 0 | 0 | 186798 | 0.538229 | 52.419752 | 0.009199 |
| Etapa 19 group1 | `_8442_/Q`, `_4782_/ZN`, `_9247_/Q`, `_5849_/ZN`, `_9248_/Q` | 89 | 0 | 0 | 186952 | 0.538672 | 52.535403 | 0.009089 |
| Etapa 19 group2 | `_6301_/ZN`, `_7165_/ZN`, `_6661_/ZN`, `_7177_/ZN`, `_6918_/ZN` | 73 | 0 | 0 | 187106 | 0.539114 | 52.574973 | 0.009913 |
| Etapa 19 group3 | `_7162_/ZN`, `_6217_/ZN`, `_5829_/ZN`, `_4979_/ZN`, `_5354_/ZN` | **48** | 0 | 0 | 187259 | 0.539557 | 52.578078 | 0.009913 |

La reparación de drivers redujo 79 violaciones de slew respecto de la referencia (62,2 %), sin introducir capacitancia o fanout. Los tres experimentos conservaron setup y hold positivos y DRC de routing limpio. El grupo 3 es el mejor candidato de esta etapa.

## Verificación física

Para `etapa19_group3`:

- Routing DRC: limpio (`05-checker-trdrc`).
- Magic DRC: limpio (`24-checker-magicdrc`).
- LVS: limpio (`29-checker-lvs`).
- Antena: 0 redes infractoras.
- XOR: limpio (`21-checker-xor`).
- PDN: VDD y VSS reportadas como conectadas en IR drop.
- SPEF: `asic/runs/etapa19_group3/12-openroad-rcx/{nom,min,max}`.
- GDS candidato: `asic/runs/etapa19_group3/final/gds/asic_top.gds`.

## KLayout DRC externo

Se localizó el deck oficial instalado en:

`gf180mcuB/libs.tech/klayout/tech/drc/rule_decks/main.drc`

de la revisión PDK `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`. Aunque LibreLane omitió su paso integrado (`KLAYOUT_DRC_RUNSET` no definido), el deck se ejecutó independientemente con KLayout 0.30.7 sobre el GDS de `etapa19_group3`, usando `table_name=main`, `conn_drc=false` y cuatro hilos. El reporte se generó en `/tmp/pochoco3/klayout_stage19/etapa19_group3.lyrdb`; contiene cero elementos `<items>` y ninguna categoría de error. El log de consola de la ejecución queda asociado a la corrida de esta etapa.

El runset utiliza `pmap` únicamente para registrar memoria; se proporcionó un shim de salida fija en `scripts/pmap` para permitir la ejecución reproducible en la imagen Docker, sin cambiar las reglas DRC.

## Cierre y limitaciones

No se consiguió cierre eléctrico completo. El mejor candidato (`etapa19_group3`) conserva **48 violaciones de slew**, aunque capacitancia y fanout son cero y todas las métricas de timing son positivas. KLayout externo, Magic DRC, LVS, antena y XOR sí resultaron limpios.

Las violaciones restantes siguen distribuidas en conos combinacionales de ROM/instrucción, salidas de registros y multiplexores. El buffering dirigido mejoró significativamente, pero seguir aumentando drivers incrementaría área y puede reducir el margen de hold. Una futura intervención debería reestructurar localmente los conos más persistentes o duplicar lógica seleccionada, con simulación RTL/post-síntesis y equivalencia ciclo a ciclo. No se implementó una modificación estructural en esta etapa.

El GDS de `etapa19_group3` es un candidato post-route verificable, no un GDS de signoff definitivo: el criterio eléctrico `slew=0` no se alcanzó y la verificación funcional específica de esta ECO física no se repitió porque no hubo cambios de RTL.

