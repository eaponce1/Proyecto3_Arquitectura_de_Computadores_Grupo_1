# Proyecto 3 — Etapa 13: reparación eléctrica dirigida

## Propuesta registrada antes de las nuevas corridas

Referencia inalterada: `asic/rom_ram_stage12_no_delay_ss.json`, corrida
`etapa12_rom_ram_no_delay_ss`. Se preservan 100 ns, utilización objetivo 40 %, ROM+RAM,
GF180MCU D, biblioteca `gf180mcu_fd_sc_mcu7t5v0` y límites eléctricos originales.

Los reportes post-route de `max_ss_125C_4v50` registran 440 violaciones slew,
dos de capacitancia y 57 de fanout. Las dos capacitancias y los 57 fanouts
pertenecen al CTS; el slew restante afecta sobre todo redes de datos e
instrucción. La peor transición es 5,405243 ns en `_1548_`, driver `_4966_/Z`
(`or2_1`), frente al límite de 3 ns. Las capacitancias de
`clknet_0_clk_i` y `clknet_3_6__leaf_clk_i` son 0,336702 y 0,234354 pF
frente a 0,2 pF. Varias hojas CTS tienen fanout 19 frente a 10.

El inventario completo, sin sumar los nueve corners entre sí, está en
`reports/stage13/baseline_residual_pins.csv` (499 filas: 440 + 2 + 57) y
`reports/stage13/baseline_residual_summary.json`. Cruza el `checks.rpt` de
`55-openroad-stapostpnr/max_ss_125C_4v50`, el netlist final y las posiciones
del DEF final (2000 unidades DEF por µm). Todas las violaciones de ese corner
están en celdas internas; no se atribuye ninguna a un puerto externo.

| Red de datos | Driver / tipo | Peor transición (ns) | Exceso sobre 3 ns (ns) | Posición del driver (µm) |
|---|---|---:|---:|---|
| `_1548_` | `_4966_/Z`, `or2_1` | 5,405243 | 2,405243 | (262,64; 360,64) |
| `net860` | `fanout860/Z`, `buf_1` | 5,158673 | 2,158673 | (179,76; 392,00) |
| `data_wdata[4]` | `_9249_/Q`, `dffrnq_1` | 4,678382 | 1,678382 | consultar CSV |
| `net1237` | `fanout1237/Z`, `buf_1` | 4,583680 | 1,583680 | consultar CSV |
| `net804` | `fanout804/Z`, `buf_1` | 4,190093 | 1,190092 | consultar CSV |
| `net300` | `fanout300/Z`, `buf_1` | 4,151794 | 1,151794 | consultar CSV |
| `_3503_` | `_7118_/ZN`, `aoi221_2` | 4,007598 | 1,007599 | consultar CSV |
| `_3462_` | `_7071_/ZN`, `aoi221_2` | 3,794204 | 0,794204 | consultar CSV |
| `_3439_` | `_7045_/ZN`, `aoi211_2` | 3,789024 | 0,789024 | consultar CSV |
| `net271` | `fanout271/Z`, `buf_1` | 3,766196 | 0,766196 | consultar CSV |

Por ejemplo, `_1548_` llega al pin `_5285_/A1`, situado en
(157,36; 490,00) µm: la separación entre instancias supera 160 µm en línea
recta. Se trata de un cono combinacional posterior a la instrucción registrada
(selector `rs2`); este dato motiva una reparación con parásitos de GRT.

| Red CTS | Driver / tipo | Carga observada | Límite | Posición del driver (µm) |
|---|---|---:|---:|---|
| `clknet_0_clk_i` | `clkbuf_0_clk_i`, `clkbuf_16` | 0,336702 pF | 0,2 pF | (292,32; 294,00) |
| `clknet_3_6__leaf_clk_i` | `clkbuf_3_6__f_clk_i`, `clkbuf_16` | 0,234354 pF | 0,2 pF | (331,52; 309,68) |
| `clknet_leaf_36_clk_i` | `clkbuf_leaf_36_clk_i`, `clkbuf_8` | fanout 19 | 10 | (535,92; 192,08) |

Las dos primeras redes son raíz y rama intermedia del CTS; las 57 redes de
fanout son hojas. La carga de reloj no es un problema de la ROM. El slew de
datos proviene de 440 pines en redes como las anteriores, con drivers de
`or2_1`, `buf_1`, `dffrnq_1` y otras celdas; la lista exacta y sus líneas del
reporte están en el CSV. Los márgenes de referencia son setup +53,646852 ns
y hold +0,054793 ns, WNS/TNS 0/0 en nueve corners, die 0,375554 mm² y área
de celdas estándar 177912 µm².

Las hojas con mayor fanout son `clknet_leaf_5_clk_i`,
`clknet_leaf_38_clk_i` y `clknet_leaf_36_clk_i`, cada una con 19 cargas
frente a límite 10; `clknet_leaf_43_clk_i` y
`clknet_leaf_3_clk_i` tienen 18. Los 57 drivers/ubicaciones se enumeran
en el CSV; no son 57 violaciones de la raíz del reloj.

La clasificación topológica de los 440 pines (fuente: JSON de la Etapa 12)
incluye 193 ligados a instrucción/fetch, 38 a memoria de datos, 13 a reset,
112 combinacionales no atribuidos a una sola unidad y 84 con raíces mixtas.
Esta clasificación de raíces no mide área por módulo. El `rs1` y `rs2` se
forman a partir de la instrucción registrada y se distribuyen a los
multiplexores del register file; tampoco se puede concluir que las 193
violaciones pertenezcan físicamente a la ROM.

En la instalación LibreLane 3.0.16, el flujo Classic contiene el paso
`OpenROAD.RepairDesignPostGRT`, gobernado por
`RUN_POST_GRT_DESIGN_REPAIR` (por defecto `false`). El script instalado
`repair_design_postgrt.tcl` ejecuta GRT, estima parásitos globales, aplica
`repair_design`, legaliza y vuelve a enrutar globalmente. Este comando repara
la lógica de diseño; no se le atribuye capacidad para corregir el CTS.

Experimentos previstos, como máximo tres:

1. **D1, datos post-GRT:** activar únicamente `RUN_POST_GRT_DESIGN_REPAIR`
   sobre la referencia. Se espera reducción del slew de datos. No se cambiará
   el margen, límite ni la SDC. El comportamiento real y número de buffers se
   comprobarán en el log original.
2. **C1, CTS:** mantener la reparación post-GRT desactivada e insertar un paso
   acotado después de CTS usando el script `stage12_clock_split.tcl`, inventariado
   en la Etapa 12. Divide exclusivamente cargas de `clknet_*` en grupos de hasta
   cuatro, en posiciones próximas a sus receptores. Límite: 400 buffers.
   Se espera menor fanout y capacitancia; setup, hold y routing pueden empeorar.
3. **DC1, combinación condicional:** ejecutar solo si D1 y C1 demuestran
   mejoras útiles e independientes. Mantendrá exactamente los mismos dos
   cambios, sin añadir una tercera variable.

La comparación definitiva usará `final/metrics.json`, los nueve reportes
`55-openroad-stapostpnr/*/checks.rpt` y los logs originales de DRC, LVS y antena.
Ningún GDSII se considerará definitivo con incumplimientos eléctricos.

## Resultados

### D1: reparación de datos post-GRT

Configuración `asic/rom_ram_stage13_postgrt.json`; corrida completa
`asic/runs/etapa13_rom_ram_postgrt/`; log de lanzamiento íntegro
`reports/stage13/etapa13_rom_ram_postgrt.log`. Única diferencia con la
referencia: `RUN_POST_GRT_DESIGN_REPAIR=true`. El paso específico
`41-openroad-repairdesignpostgrt/openroad-repairdesignpostgrt.log`, líneas
62–77, registra `repair_design -max_wire_length 0 -slew_margin 10
-cap_margin 10`, **una celda redimensionada y ningún buffer insertado**.
Esos porcentajes son los valores predeterminados del paso instalado, no
una relajación de límites Liberty ni SDC. Su estimación global detectó una
violación de slew en ese momento, frente a las 410 observadas finalmente
con RC extraído: la estimación post-GRT no captura el residual post-route.

Resultado físico final: slew **410** (−30), capacitancia **3** (+1), fanout
**57** (igual). La peor transición subió de 5,405243 a **5,421193 ns**,
la peor capacitancia de 0,336702 a **0,339210 pF**. Peor slack setup
+53,159008 ns y hold +0,054793 ns; WNS/TNS 0/0 en los nueve corners.
Área stdcell 177917 µm² (+5 µm²); die 375554 µm², utilización 51,2638 %;
GRT uso 24,60 %, overflow H/V/total 0/0/0. Routing DRC, Magic DRC,
LVS y antena: cero. El netlist de síntesis es idéntico a la referencia
según `reports/stage13/etapa13_rom_ram_postgrt/summary.json`.

El menor conteo de slew no compensa el aumento de capacitancia ni la peor
severidad. D1 no es candidata de cierre ni una mejora integral demostrada.
La tercera prueba combinada queda condicionada al resultado CTS y a que
ambos cambios ofrezcan un beneficio técnico justificable.

El tercer exceso de capacitancia es precisamente la red de datos `_1548_`:
0,202938 pF, exceso 0,002938 pF, driver `_4966_`. Tras el único sizing,
su slew deja de ser el peor; el peor pasa a `net860` (5,421193 ns).
Esto confirma que la modificación atacó una ruta real, pero trasladó el
incumplimiento de esa red a capacitancia y no resolvió el conjunto.
La diferencia concreta de netlist final es `_4966_`: `or2_1` en la
referencia y `or2_2` en D1 (ambos `final/nl/asic_top.nl.v:23415–23416`).

### C1: distribución CTS, primer lanzamiento y corrección de instrumentación

El primer lanzamiento de C1 (`etapa13_rom_ram_cts`) terminó con código 1
en `36-openroad-stage12clocksplit`, antes del enrutamiento y del STA final.
Log original conservado: `reports/stage13/etapa13_rom_ram_cts.log` y
`asic/runs/etapa13_rom_ram_cts/36-openroad-stage12clocksplit/openroad-stage12clocksplit.log`.
El inventario localizó 265 inserciones planeadas, dentro del máximo 400.
Al insertar el primer buffer, el script falló con
`Error: stage12_clock_split.tcl, 54 Failed to create clknet_stage12_0`.
No es evidencia de una violación física: el script exigía que el nombre real
de la red coincidiera literalmente con el nombre base solicitado. El código
de OpenROAD crea nombres únicos cuando se pasa `-net_name`.
La comprobación se corrigió para leer la red a través de los pines de carga
reconectados y verificar que todos pertenezcan a la misma red nueva. No se
modificó el algoritmo de agrupación ni el número planificado de buffers.
Se preservó el intento fallido y se inició `etapa13_rom_ram_cts_retry`
con una etiqueta independiente; ambos son el mismo experimento CTS.

Fuente del comportamiento de nombres de OpenROAD, revisión instalada:
https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD/dcf36133a369abc8f3c5e5738cd4d82e4903c0e0/src/odb/src/db/dbInsertBuffer.cpp

### C1: resultado físico completo del reintento

Configuración `asic/rom_ram_stage13_cts.json`; corrida
`asic/runs/etapa13_rom_ram_cts_retry/`; log completo
`reports/stage13/etapa13_rom_ram_cts_retry.log`. La única variable física
respecto de la referencia es el paso de distribución CTS post-CTS.
El log `36-openroad-stage12clocksplit/openroad-stage12clocksplit.log`
registra **265 buffers `clkbuf_4` insertados** (líneas 12 y 557), con
comprobación individual de conexión. No se modificaron RTL, programa,
frecuencia, límites ni SDC.

Resultado post-route: **468 slew, 1 capacitancia y 0 fanout**. Los 57
fanouts desaparecen, al igual que ambas capacitancias de reloj. La única
capacitancia remanente en `max_ss` corresponde a la red de datos
`_1548_`, driver `_4966_/Z`, **0,201080 pF** frente a 0,2 pF:
exceso 0,001080 pF. El peor slew es **5,536282 ns** en esa misma red,
exceso 2,536282 ns; `net860` le sigue con 5,491123 ns. Por tanto,
el CTS sí resolvió el fanout pero no la transición de datos.

Área stdcell 186061 µm² (+8149 µm²), die 375554 µm², utilización real
53,6104 % (+2,3479 puntos porcentuales); uso de recursos GRT 25,14 %,
overflow H/V/total 0/0/0. El routing detallado inició con 2856
violaciones y terminó con **0**; esto es evidencia de convergencia, no un
DRC inicial limpio. Routing DRC final, Magic DRC, LVS, antena y XOR:
**0**. El flujo Classic terminó con código 0. KLayout DRC integrado no
tenía runset configurado y el deck externo no se ejecutó para C1 porque
mantiene 469 incumplimientos eléctricos; no se le atribuye aprobación
KLayout. Netlist sintetizado idéntico a la referencia; 874 FF.
El paso adicional ejecutó detailed placement y el resultado final informa
`magic__illegal_overlap__count=0`. El netlist físico final contiene 265
instancias `clkbuf_4`, ausentes en la referencia.

Peor slack real setup **+52,430605 ns** y hold **+0,010418 ns**. WNS/TNS
setup y hold son **0/0 ns en cada uno de los nueve corners**; la holgura
de hold se redujo desde +0,054793 ns, así que C1 exige cautela aun cuando
no exista violación de timing. Tabla completa de los resultados STA:

| Corner | Setup WS (ns) | Hold WS (ns) | Slew | Cap | Fanout |
|---|---:|---:|---:|---:|---:|
| nom_tt_025C_5v00 | +72,496329 | +0,216961 | 0 | 0 | 0 |
| nom_ss_125C_4v50 | +54,515778 | +0,657682 | 279 | 0 | 0 |
| nom_ff_n40C_5v50 | +75,083025 | +0,025043 | 0 | 0 | 0 |
| min_tt_025C_5v00 | +72,611679 | +0,215862 | 0 | 0 | 0 |
| min_ss_125C_4v50 | +56,260530 | +0,655802 | 165 | 0 | 0 |
| min_ff_n40C_5v50 | +75,160339 | +0,029192 | 0 | 0 | 0 |
| max_tt_025C_5v00 | +72,357496 | +0,201933 | 21 | 1 | 0 |
| max_ss_125C_4v50 | +52,430605 | +0,653470 | 468 | 1 | 0 |
| max_ff_n40C_5v50 | +74,989702 | +0,010418 | 0 | 1 | 0 |

Las cifras de la tabla provienen de
`reports/stage13/etapa13_rom_ram_cts_retry/corners.csv` y las métricas
de `final/metrics.json`. WNS=0 es el valor truncado de LibreLane; la
columna WS muestra la holgura real positiva.

### Comparación y decisión

| Corrida | Estado | Slew | Cap | Fanout | Peor slew (ns) | Peor cap (pF) | Área stdcell (µm²) | Util. real | Setup/hold WS mínimos (ns) |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Referencia Etapa 12 | completa | 440 | 2 | 57 | 5,405243 | 0,336702 | 177912 | 51,2625 % | +53,646852 / +0,054793 |
| D1 post-GRT | completa | 410 | 3 | 57 | 5,421193 | 0,339210 | 177917 | 51,2638 % | +53,159008 / +0,054793 |
| C1 CTS inicial | falló antes de routing | — | — | — | — | — | — | — | — |
| C1 CTS reintento | completa | 468 | 1 | 0 | 5,536282 | 0,201080 | 186061 | 53,6104 % | +52,430605 / +0,010418 |

Datos fuente en `reports/stage13/comparison.csv` y
`reports/stage13/timing_nine_corners.csv`. En las tres corridas completas
(referencia, D1 y C1 reintento), setup/hold WNS/TNS son 0/0 ns en nueve
corners, GRT overflow 0/0/0, routing DRC/Magic DRC/LVS/antena 0.
La corrida C1 inicial carece de estos resultados; el guion refleja ese
estado y no un valor cero.

El reintento CTS reduce 57 fanouts y una capacitancia netos frente a la
referencia, pero añade 28 slews y empeora la peor transición 0,131039 ns.
D1 reduce 30 slews, pero añade una capacitancia y empeora la peor
transición. Son resultados cruzados, sin candidato que domine todos los
criterios. La combinación no se ejecutó: **D1 no demostró una mejora
integral**, C1 dejó más slew y el máximo de tres lanzamientos ya se usó
contando el fallo instrumental. `asic/rom_ram_stage13_combined.json`
queda únicamente como configuración preparada, sin corrida ni resultados.

La **mejor referencia integral demostrada sigue siendo
`etapa12_rom_ram_no_delay_ss`** por menor slew, menor área y mejor
holgura de hold, con KLayout externo previamente limpio. C1 es una
alternativa experimental útil para estudiar el CTS porque elimina todos
los fanouts, pero no reemplaza la referencia reglamentaria ni constituye
cierre. El total de incumplimientos baja de 499 a 469 en C1, una reducción
neta de 30, pero la magnitud y el tipo de los residuos importan más que
ese agregado. En ninguna configuración hay cero violaciones eléctricas.

No se modificaron `game.s` ni el RTL funcional; los netlists de síntesis
son idénticos tras la normalización jerárquica ya documentada en Etapa 12.
Por ello no se repitieron las 16 pruebas Python ni la simulación de las
diez rondas, condicionadas por el enunciado a cambios de RTL. No se
afirma equivalencia formal de los netlists físicos alternativos.
Ninguno de los GDSII generados es definitivo. La siguiente intervención
justificada debe actuar sobre `_1548_`, `net860` y otros drivers de
datos usando RC post-route o una estimación de GRT calibrada: el
`repair_design` post-GRT solo vio una violación donde el STA extraído
vio centenares. Cualquier nuevo buffer o sizing debe revalidar los nueve
corners, especialmente el margen de hold de C1, además de DRC/LVS/antena
y KLayout externo si llegara a cero eléctrico.
Se siguen usando las restricciones SDC genéricas de LibreLane, sin
`PNR_SDC_FILE` ni `SIGNOFF_SDC_FILE` de interfaz ASIC específicos; estas
hipótesis tampoco permiten declarar signoff integral.

### Reproducción y rutas originales

Desde WSL, en `/tmp/pochoco3` (bind mount del proyecto principal):

```sh
python3 scripts/stage13_diagnose.py
python3 scripts/stage13_run.py asic/rom_ram_stage13_postgrt.json --tag etapa13_REPRO_postgrt
python3 scripts/stage13_run.py asic/rom_ram_stage13_cts.json --tag etapa13_REPRO_cts
python3 scripts/stage12_audit.py etapa13_REPRO_postgrt --report-root reports/stage13
python3 scripts/stage12_audit.py etapa13_REPRO_cts --report-root reports/stage13
```

El lanzador rechaza etiquetas ya existentes y registra hashes de todas
las fuentes/configuraciones en `reports/stage13/<tag>_manifest.json`.
Para los resultados originales, usar los tags indicados en la tabla,
no ejecutar sobre ellos. Logs paso a paso:
`asic/runs/<tag>/<número>-<paso>/*.log`; STA y eléctricos:
`asic/runs/<tag>/*-openroad-stapostpnr/<corner>/checks.rpt`;
métricas finales `asic/runs/<tag>/final/metrics.json`; GDSII candidato
`asic/runs/<tag>/final/gds/asic_top.gds`. Las nueve filas por corrida y
el diagnóstico por pin están en `reports/stage13/`.
