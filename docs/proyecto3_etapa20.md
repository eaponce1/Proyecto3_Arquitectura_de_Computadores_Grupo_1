# Proyecto 3 — Etapa 20: reparación localizada de slew

## Alcance y punto de partida

Se conservó íntegramente la corrida `etapa19_group3` y se trabajó mediante ECO físico sobre su estado post-routing. Todas las corridas usaron `CLOCK_PERIOD=100 ns`, `FP_CORE_UTIL=40`, `PDK=gf180mcuD`, biblioteca `gf180mcu_fd_sc_mcu7t5v0` y `MemoryArchitecture=1` (ROM combinacional + RAM reducida). No se modificaron RTL, Assembly, las diez rondas ni el informe LaTeX.

La referencia tenía 48 violaciones de slew, capacitancia 0 y fanout 0. El análisis post-route con SPEF real (`reports/stage19/group3/slew_by_net.csv` y `slew_violations.csv`) mostró 48 pines infractores, 17 redes distintas y 52 apariciones al considerar ambos corners SS donde se reportaron violaciones. Las redes eran principalmente conos de decodificación/ROM; no se observaron violaciones de capacitancia ni de fanout.

## Diagnóstico

Las cinco redes con mayor severidad en el estado inicial fueron:

| Red | Violaciones/pines | Peor slew (ns) | Límite (ns) | Driver y celda | Clasificación |
|---|---:|---:|---:|---|---|
| `_2886_` | 4 | 3,498744 | 3,0 | `_6423_/ZN`, `aoi211_1` | instrucción/ROM |
| `eco_buffer_48_net` | 4 | 3,435786 | 3,0 | `_7165_/ZN`, `aoi221_1` | instrucción/ROM |
| `_1378_` | 4 | 3,153470 | 3,0 | `_4763_/ZN`, `oai221_1` | instrucción/ROM |
| `_1354_` | 4 | 3,123371 | 3,0 | `_4739_/ZN`, `oai21_1` | instrucción/ROM |
| `_1326_` | 4 | 3,049156 | 3,0 | `_4711_/ZN`, `aoi21_1` | instrucción/ROM |

También aparecieron `_1464_` (3,035001 ns), `_3407_` (3,287734 ns), `_3400_` (3,172999 ns), `_3462_` (3,157636 ns), `_3482_` (3,123814 ns), `_3336_` (3,092836 ns), `_3298_` (3,021988 ns), `_0072_` (3,222427 ns), `_3399_` (3,217172 ns), `_3521_` (3,164398 ns), `_1071_` (3,140315 ns) y `_0069_` (3,124134 ns). Las etiquetas `_0072_`, `_1071_` y `_0069_` tienen clasificación mixta `data/register-file; instruction/ROM`; las demás corresponden al cono de instrucción/ROM. La separación se obtuvo de la columna `classification` del CSV, no por inferencia de nombres.

La medición del flujo y la tabla CSV usan el mismo STA post-route y los mismos SPEF generados por RCX. El flujo integrado de LibreLane omitió su paso KLayout porque `KLAYOUT_DRC_RUNSET` no estaba definido para gf180mcuD; por ello se ejecutó separadamente el deck externo GF180MCU `main.drc`.

## Reparación controlada

Se utilizó exclusivamente la inserción ECO de buffers legales `gf180mcu_fd_sc_mcu7t5v0__buf_4`, seguida de legalización implícita, detailed routing, RCX y STA post-route. Cada grupo se aplicó sobre el estado detallado de la corrida inmediatamente anterior.

| Corrida | Targets principales | Slew | Cap. | Fanout | Setup WNS mínimo (ns) | Hold WNS mínimo (ns) | Área stdcell | Utilización | DRC/LVS/antena |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| `etapa19_group3` (baseline) | — | 48 | 0 | 0 | +52,578078 | +0,009913 | 187259 | 0,539557 | 0/0/0 |
| `etapa20_group1` | `_6423_`, `_4763_`, `_4739_`, `_4711_`, `_4849_` | 30 | 0 | 0 | +53,072702 | +0,009178 | 187413 | 0,540000 | 0/0/0 |
| `etapa20_group2` | `_7009_`, `_7001_`, `_7071_`, `_7094_`, `_6933_` | 15 | 0 | 0 | +53,044177 | +0,007749 | 187567 | 0,540443 | 0/0/0 |
| `etapa20_group3` (mejor) | `_6892_`, `_7000_`, `_7139_`, `_4456_`, `_5153_` | 4 | 0 | 0 | +53,046152 | +0,006714 | 187720 | 0,540886 | 0/0/0 |

Los targets fueron seleccionados a partir de los drivers de mayor severidad que aún no habían sido intervenidos. No se alteró el árbol de reloj ni se cambiaron restricciones Liberty/SDC. La mejora acumulada fue 48→30→15→4 violaciones de slew; capacitancia y fanout permanecieron en cero. La última ejecución conservó margen positivo de setup y hold en los nueve corners exigidos por el flujo.

## Violaciones residuales

El STA final de `etapa20_group3` con SPEF real reporta cuatro pines infractores en dos redes:

| Corner | Red | Pin/driver | Celda | Slew (ns) | Límite (ns) | Slack (ns) |
|---|---|---|---|---:|---:|---:|
| `max_ss_125C_4v50` | `eco_buffer_48_net` | `_7165_/ZN` | `aoi221_1` | 3,435396 | 3,0 | −0,435396 |
| `max_ss_125C_4v50` | `eco_buffer_48_net` | `eco_buffer_48/I` | `buf_4` | 3,435396 | 3,0 | −0,435396 |
| `max_ss_125C_4v50` | `_0072_` | `_5187_/ZN` | `aoi22_1` | 3,074548 | 3,0 | −0,074548 |
| `max_ss_125C_4v50` | `_0072_` | `_9262_/D` | `dffrnq_1` | 3,074549 | 3,0 | −0,074549 |

El corner `nom_ss_125C_4v50` también conserva la red `eco_buffer_48_net` (3,195159 ns, −0,195159 ns). Las dos redes residuales son, por tanto, cargas de datos/instrucción: `eco_buffer_48_net` ya contiene un buffer ECO y `_0072_` alimenta una entrada de registro. El buffering de los tres grupos redujo las redes restantes a un conjunto pequeño, pero no logró reducir sus transiciones bajo 3 ns sin una intervención estructural o un driver/capacidad diferente.

## Verificación física y evidencias

- SPEF post-route y logs de RCX/STA: `asic/runs/etapa20_group3/12-openroad-rcx/` y `asic/runs/etapa20_group3/13-openroad-stapostpnr/`.
- GDSII candidato: `asic/runs/etapa20_group3/final/gds/asic_top.gds`.
- Routing DRC, Magic DRC, LVS, antena y XOR: cero errores en `asic/runs/etapa20_group3/final/metrics.json` y pasos `05`, `22`, `29`, `21`.
- Conectividad PDN: el reporte IR de `14-openroad-irdropreport` indica todas las formas VDD y VSS conectadas.
- KLayout DRC externo: ejecutado con el deck GF180MCU `.../gf180mcuB/libs.tech/klayout/tech/drc/rule_decks/main.drc`; reporte sin elementos en `reports/stage20/etapa20_group3.lyrdb`.
- KLayout integrado de LibreLane: omitido por `KLAYOUT_DRC_RUNSET` no definido; no se presenta como sustituto del deck externo.

Las inserciones ECO no cambian el RTL. Las pruebas funcionales RTL/post-síntesis previas siguen siendo aplicables al diseño lógico; no se ejecutó una nueva comparación ciclo a ciclo específica para cada ECO físico y, por tanto, no se afirma una nueva prueba de equivalencia formal.

## Estado de cierre

No se consiguió cierre eléctrico completo. La mejor configuración demostrada es `etapa20_group3`: capacitancia=0 y fanout=0, pero quedan 4 violaciones de slew (dos redes, principalmente `eco_buffer_48_net`). El GDSII es un candidato físicamente verificado en DRC/LVS/antena/XOR y KLayout externo, no un resultado de signoff eléctrico definitivo. La siguiente intervención técnicamente justificada sería reemplazar o duplicar selectivamente los drivers de esas dos redes, o reestructurar localmente el cono que alimenta `_0072_`, validando nuevamente SPEF, STA y equivalencia funcional.

## Reproducción

Las configuraciones son `asic/rom_ram_stage20_group1.json`, `asic/rom_ram_stage20_group2.json` y `asic/rom_ram_stage20_group3.json`. Para reproducir una etapa se debe iniciar desde el `state_out.json` de detailed routing de la etapa anterior y ejecutar `librelane --from odb.insertecobuffers` con el tag correspondiente. Todos los logs originales permanecen bajo `asic/runs/etapa20_group1`, `etapa20_group2` y `etapa20_group3`; los CSV de diagnóstico están en `reports/stage20/group1`, `group2` y `group3`.
