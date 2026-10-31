# Proyecto 3 — Etapa 17: reparación progresiva de slew

## Alcance y punto de partida

Esta etapa conserva todas las corridas anteriores y trabaja exclusivamente sobre estados físicos post-route. La referencia es `etapa16_eco_top5`, configuración `asic/rom_ram_stage16_eco_top5.json`, con `CLOCK_PERIOD=100 ns`, `FP_CORE_UTIL=40`, GF180MCU-D y `gf180mcu_fd_sc_mcu7t5v0`. No se modificaron RTL, Assembly, el informe LaTeX ni el programa de diez rondas.

La baseline presentó 377 violaciones de slew, cero de capacitancia y cero de fanout. El diagnóstico final de la baseline agrupó 673 apariciones en tres corners SS (`max_ss_125C_4v50`, `min_ss_125C_4v50` y `nom_ss_125C_4v50`) sobre 65 redes físicas distintas. La red con mayor severidad fue `net300`, con transición 4.803081 ns frente al límite 3 ns. El conteo de apariciones no debe confundirse con el número de redes únicas.

## Diagnóstico

Los artefactos reproducibles están en `reports/stage17/group1/`, `group2/` y `group3/`, generados por `scripts/stage16_diagnose.py` a partir del netlist final y de los reportes STA post-route. En la baseline, las redes más repetidas incluyeron `_1029_` (driver `_4414_/Z`, `and2_1`, 22 apariciones), `net1237` (driver `fanout1237/Z`, `buf_1`, 21), `_0965_` (driver `_4348_/ZN`, `nand4_1`, 21), `_2362_` (driver `_5863_/ZN`, `nand2_1`, 20), `net271` (driver `fanout271/Z`, `buf_1`, 18) y `net1342` (driver `fanout1342/Z`, `buf_1`, 18). También aparecen señales de datos del register file y salidas de la RAM (`data_wdata[*]`, `u_ram.a_rdata_o[*]`). La clasificación heurística las sitúa principalmente en los conos de instrucción/ROM y data/register-file; no se observaron violaciones de capacitancia o fanout en las métricas finales.

La distribución demuestra que el problema residual no está concentrado en una sola red: después de las primeras ECO persisten decenas de redes, incluyendo drivers combinacionales (`and2`, `nand*`, `aoi*`, `oai*`), buffers de fanout y salidas de registros. Por ello un buffer único sobre `net300` no garantiza cierre global; algunos caminos requieren más capacidad de driver o reestructuración lógica, que no se implementó en esta etapa por el riesgo funcional.

## Experimentos controlados

Cada grupo parte del estado detalladamente ruteado del grupo anterior, inserta cinco buffers `gf180mcu_fd_sc_mcu7t5v0__buf_2` mediante `Odb.InsertECOBuffers`, vuelve a rutear, extrae SPEF con RCX y ejecuta STA post-route en los nueve corners. Las configuraciones son independientes y quedan en `asic/rom_ram_stage17_group1.json`, `asic/rom_ram_stage17_group2.json` y `asic/rom_ram_stage17_group3.json`.

| Estado | Redes/Drivers intervenidos | Slew | Cap. | Fanout | Área stdcell | Utilización | Setup mínimo (ns) | Hold mínimo (ns) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Etapa 16 baseline | `fanout804/Z`, `_5832_/ZN`, `fanout943/Z`, `_6231_/ZN`, `_8474_/Q` | 377 | 0 | 0 | 186184 | 0.536458 | 52.474723 | 0.010312 |
| Grupo 1 | `_4414_/Z`, `fanout1237/Z`, `_4348_/ZN`, `_5863_/ZN`, `fanout271/Z` | 327 | 0 | 0 | 186272 | 0.536711 | 52.398272 | 0.010258 |
| Grupo 2 | `_4414_/Z`, `fanout1237/Z`, `_4348_/ZN`, `_5863_/ZN`, `fanout271/Z` | 283 | 0 | 0 | 186359 | 0.536964 | 52.510676 | 0.010300 |
| Grupo 3 | `fanout1342/Z`, `_6274_/ZN`, `_5852_/ZN`, `_4353_/ZN`, `_4867_/ZN` | **248** | 0 | 0 | 186447 | 0.537217 | 52.602908 | 0.010302 |

El grupo 1 redujo 50 violaciones respecto de la baseline, el grupo 2 redujo otras 44 y el grupo 3 redujo otras 35. En conjunto se eliminaron 129 violaciones de slew (34.2 % respecto de 377), manteniendo capacitancia y fanout en cero. El área aumentó 263 unidades de área estándar y la utilización 0.000759. Los márgenes de timing permanecieron positivos en todos los corners; los mínimos mostrados son los mínimos de las propiedades `timing__setup__ws__corner:*` y `timing__hold__ws__corner:*` de `final/metrics.json`.

> Nota: el nombre de “grupo 3” corresponde al tercer experimento permitido. Los drivers se seleccionaron a partir del CSV producido después del grupo anterior; por eso algunos nombres físicos cambian o reaparecen al relegalizar y rerutear.

## Verificación física y SPEF

Las tres corridas completaron LibreLane 3.0.16 y generaron SPEF en `asic/runs/<tag>/12-openroad-rcx/{nom,min,max}`. Para el grupo 3, el flujo produjo:

- Routing DRC (`05-checker-trdrc`): limpio.
- Magic DRC (`24-checker-magicdrc`): limpio.
- LVS (`29-checker-lvs`): limpio.
- Antena: cero redes infractoras (`antenna__violating__nets=0`); queda el warning genérico de un pin de `asic_top` sin información de antenna gate.
- XOR: limpio (`21-checker-xor`).
- Alimentación: el informe IR drop indica todas las formas VDD/VSS conectadas.
- KLayout DRC interno: no ejecutado porque `KLAYOUT_DRC_RUNSET` no está definido; `klayout__drc_error__count` no está disponible. Por tanto no se afirma un resultado KLayout externo para estas nuevas corridas.

Los GDS candidatos se encuentran en `asic/runs/etapa17_group{1,2,3}/final/gds/asic_top.gds`. Cada GDS corresponde a su propia extracción SPEF y netlist, pero ninguno es definitivo mientras existan violaciones de slew y falte la ejecución del deck KLayout externo.

## Resultado y limitaciones

No se consiguió cierre eléctrico completo. El mejor resultado de los tres experimentos es `etapa17_group3`, con 248 violaciones de slew, cero de capacitancia y cero de fanout. El objetivo de slew=0 no se alcanzó, aunque la reparación progresiva fue monotónicamente beneficiosa en estos tres puntos.

La evidencia indica que el slew residual está distribuido entre muchos conos combinacionales de ROM/instrucción, register file y datos, no solo en una red. La inserción indiscriminada de buffers aumentaría área y podría crear nuevas cargas; además, el margen de hold mínimo es cercano a cero (0.010302 ns). La siguiente intervención técnicamente justificada sería una ECO con selección de drivers de mayor capacidad y/o una reestructuración localizada de los conos más repetidos, validada primero en una copia del estado del grupo 3. No se realizó porque excede el máximo de tres grupos solicitado y requiere un análisis de equivalencia funcional adicional.

Las pruebas funcionales RTL y post-síntesis de la Etapa 7 (16 pruebas Python y 6 casos Icarus, `mismatches=0`) siguen siendo aplicables: esta etapa solo modifica el layout mediante ECO y no cambia RTL, Assembly, ISA ni la imagen de memoria. Deben repetirse si se adopta una futura modificación RTL.

## Comandos reproducibles

Desde el directorio del proyecto:

```text
python scripts/stage16_diagnose.py --tag etapa17_group3
```

Las corridas físicas se lanzaron con LibreLane 3.0.16 en Docker, usando el estado `02-openroad-detailedrouting-1/state_out.json` de la corrida previa y `--from odb.insertecobuffers`; los logs completos están bajo `asic/runs/etapa17_group1`, `etapa17_group2_retry` y `etapa17_group3`.

