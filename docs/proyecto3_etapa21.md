# Proyecto 3 — Etapa 21: cierre de las violaciones residuales

## Referencia y diagnóstico

Se partió del estado post-route de `etapa20_group3` (`CLOCK_PERIOD=100 ns`, `FP_CORE_UTIL=40`, ROM+RAM, GF180MCU `gf180mcu_fd_sc_mcu7t5v0`). El STA con SPEF real reportaba cuatro pines en dos redes:

| Red | Driver/celda | Receptores | Corner | Slew | Límite | Capacitancia/fanout |
|---|---|---|---|---:|---:|---:|
| `eco_buffer_48_net` | `_7165_/ZN`, `aoi221_1`; buffer existente `eco_buffer_48`, `buf_4` | `eco_buffer_48/I` y la salida del buffer | `max_ss_125C_4v50` y `nom_ss_125C_4v50` | 3,435396 ns (máx.) | 3 ns | 0 / 0 |
| `_0072_` | `_5187_/ZN`, `aoi22_1` | `_9262_/D` (`dffrnq_1`) | `max_ss_125C_4v50` | 3,074549 ns | 3 ns | 0 / 0 |

La transición observada corresponde al pin del driver y se propaga a la carga; no había violaciones de capacitancia ni fanout que reparar. La red `eco_buffer_48_net` ya contenía un `buf_4`, por lo que se evaluó una celda de mayor capacidad (`buf_8`). La biblioteca instalada confirma la existencia de `buf_1`, `buf_2`, `buf_3`, `buf_4`, `buf_8`, `buf_12`, `buf_16` y `buf_20`. Las coordenadas de los drivers en el DEF post-route fueron `_7165_` en (706720,399840) y `_5187_` en (141120,399840), en unidades de DEF; el flujo no entregó una descomposición independiente de resistencia por segmento en el CSV de violaciones.

## Experimentos

Cada experimento insertó buffers ECO legales, ejecutó legalización, detailed routing, RCX y STA post-route en los nueve corners. La baseline y todos los estados físicos fueron conservados.

| Corrida | Intervención | Slew | Cap. | Fanout | Setup WNS mínimo (ns) | Hold WNS mínimo (ns) | Área stdcell | Utilización | DRC/LVS/antena |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| `etapa20_group3` | Baseline | 4 | 0 | 0 | +53,046152 | +0,006714 | 187720 | 0,540886 | 0/0/0 |
| `etapa21_eco48` | `_7165_/ZN` → `buf_8` | 6 | 0 | 0 | +53,047829 | +0,006714 | 187777 | 0,541050 | 0/0/0 |
| `etapa21_0072` | `_5187_/ZN` → `buf_8` | 2 | 0 | 0 | +53,051999 | +0,006714 | 187777 | 0,541050 | 0/0/0 |
| `etapa21_combined` | Estado anterior + `_7165_/ZN` → `buf_4` | **0** | **0** | **0** | **+53,053929** | **+0,006720** | 187808 | 0,541139 | 0/0/0 |

El experimento `eco48` fue descartado: el buffer `buf_8` produjo una cadena adicional (`eco_buffer_72_net`/`eco_buffer_64_net`) y aumentó el conteo a seis. El experimento `_0072_` redujo las violaciones a dos, dejando únicamente `eco_buffer_48_net`. La combinación con un `buf_4` adicional eliminó todas las violaciones de slew sin producir hold negativo.

## Verificación integral de la mejor corrida

La corrida `etapa21_combined` terminó correctamente y su `final/metrics.json` reporta:

- Slew, capacitancia y fanout: 0/0/0.
- Setup y hold: sin violaciones en los nueve corners; peores WNS +53,053929 ns y +0,006720 ns.
- Routing DRC: 0.
- Magic DRC: 0.
- LVS: 0 errores.
- Antena: 0 redes infractoras.
- XOR: limpio.
- PDN: los reportes IR indican todas las formas VDD y VSS conectadas.

GDSII, netlist y SPEF corresponden al mismo tag:

- GDSII: `asic/runs/etapa21_combined/final/gds/asic_top.gds`.
- SPEF: `asic/runs/etapa21_combined/12-openroad-rcx/{min,nom,max}/`.
- STA: `asic/runs/etapa21_combined/13-openroad-stapostpnr/`.
- Logs y reportes completos: `asic/runs/etapa21_combined/`.

KLayout DRC integrado de LibreLane se omitió porque `KLAYOUT_DRC_RUNSET` no está definido para gf180mcuD. Se ejecutó independientemente el deck externo GF180MCU empleado en las etapas anteriores sobre el GDS de `etapa21_combined`; el reporte no contiene elementos y se conserva en `reports/stage21_etapa21_combined.lyrdb`. Por tanto, la verificación KLayout externa fue limpia, mientras que la métrica integrada permanece sin reportar.

## Verificación funcional

Las pruebas Python disponibles (`tests.test_game` y `tests.test_assembler`) se ejecutaron con `python3 -m unittest -q` y pasaron: 12 pruebas, estado `OK`. No se modificó RTL ni Assembly. Se regeneró el adaptador del netlist desde `asic/runs/etapa21_combined/final/nl/asic_top.nl.v`; la compilación Icarus del testbench falló porque el netlist post-route está aplanado y el testbench requiere la jerarquía interna `gate.u_pochoco_soc.u_core.g_asic_regfile...`. La prueba histórica `make stage7-run` tampoco puede reconstruirse porque falta el artefacto de síntesis de Etapa 7. En consecuencia, no se afirma una nueva comparación ciclo a ciclo específica del GDS/ECO; las inserciones son exclusivamente físicas y el XOR del flujo fue limpio.

## Estado de cierre

Se alcanzó el cierre eléctrico del macro bajo las restricciones disponibles: slew=0, capacitancia=0 y fanout=0 con timing post-route positivo y verificaciones físicas limpias, incluida la ejecución externa de KLayout. El GDSII es un candidato de macro ASIC verificado; no equivale a certificación de fabricación de un chip completo con pads, modelos de I/O y restricciones de interfaz ASIC específicas. La corrida integrada no reporta KLayout por la variable ausente, y la simulación funcional post-síntesis del ECO debe repetirse cuando se recupere el netlist histórico requerido.

## Reproducción

Configuraciones: `asic/rom_ram_stage21_eco48.json`, `asic/rom_ram_stage21_0072.json` y `asic/rom_ram_stage21_combined.json`. Los comandos reproducibles usan `librelane:3.0.16`, `--manual-pdk`, `--from odb.insertecobuffers` y los `state_out.json` de `etapa20_group3` o `etapa21_0072`. Las métricas, logs y estados permanecen bajo `asic/runs/etapa21_eco48`, `asic/runs/etapa21_0072` y `asic/runs/etapa21_combined`; los diagnósticos CSV de las dos pruebas con violaciones están en `reports/stage21/eco48` y `reports/stage21/0072`.
