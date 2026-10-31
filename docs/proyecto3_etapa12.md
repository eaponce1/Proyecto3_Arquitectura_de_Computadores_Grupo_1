# Proyecto 3 — Etapa 12: intento final de cierre eléctrico

Fecha de inicio: 25 de octubre de 2026 (America/Santiago).

## Resultado final

Se completaron exactamente tres experimentos físicos y se preservó la
baseline. El mejor es **etapa12_rom_ram_no_delay_ss**, configuración
asic/rom_ram_stage12_no_delay_ss.json: 100 ns y FP_CORE_UTIL=40.
Reduce slew/cap/fanout de 2695/10/58 a **440/2/57**: elimina 2255/8/1
incumplimientos, respectivamente. No hay cierre eléctrico completo y no
se acepta ninguna excepción. El GDSII sigue siendo candidato.

Setup/hold cumplen en nueve corners, con WNS=TNS=0. Peores slacks reales:
setup +53,646852 ns y hold +0,054793 ns. Die 0,375554 mm²; área stdcell
177912 µm²; utilización real 51,2625 %. Routing DRC, Magic DRC, LVS, antena
y XOR son cero. El **KLayout externo también terminó limpio**, con el mismo
deck sin modificar de Etapa 9 y KLayout 0.30.7.

La reducción de conteos no elimina todas las severidades: el fanout máximo
sube de 18 a 19 y el margen de hold baja, aunque continúa siendo positivo.
No puede presentarse esta configuración como corrida reglamentaria definitiva
con signoff aprobado. Sí es la mejor candidata demostrada de esta etapa.

## Baseline y diagnóstico previo a modificar configuraciones

Referencia intacta: `asic/runs/etapa9_rom_ram_util40_debounce/`.
ROM+RAM original, 100 ns, FP_CORE_UTIL=40, GF180MCU D,
`gf180mcu_fd_sc_mcu7t5v0`. No se usa el register file particionado.

Fuentes primarias: `55-openroad-stapostpnr/<corner>/checks.rpt`,
`final/metrics.json`, `final/nl/asic_top.nl.v`, `final/sdc/asic_top.sdc`.
El diagnóstico previo también se puede contrastar con
`reports/stage9/electrical_util40_debounce.{json,csv}`.

La baseline tiene 2695 pines con slew excesivo, 10 redes con capacitancia
excesiva y 58 drivers con fanout excesivo en max_ss. Son controles distintos:
transición (ns), capacitancia (pF) y carga de fanout (unidad Liberty). Límites
efectivos de la SDC: 3 ns, 0,2 pF y 10, respectivamente (líneas 75–77).

El cruce pin a pin en max_ss encuentra **cero violaciones sobre terminales
externos** para los tres tipos. Los 2695/10/58 incumplimientos corresponden
a pines internos de celdas. Esto no valida una interfaz de pads/package:
se conserva la SDC genérica, sin PNR_SDC_FILE ni SIGNOFF_SDC_FILE propios.
Entrada/salida 20 ns, carga de salida 0,07291 pF y drivers genéricos son
hipótesis del flujo, no especificaciones externas demostradas.

Las diez redes con más pines de slew violados son net385, net494, net453,
net406, net389, net441, net445, net461, net515 y net525, con 11 pines cada una.
Todas tienen drivers fanoutNNN/Z de tipo dlyb_1. La peor transición entre
estas diez es 6,292998 ns (net385), con exceso 3,292998 ns. net385/net494/net406/net389
proceden de los bits registrados [18:15] (rs1); las otras, de [23:20] (rs2).
Conducen entradas de AOI22/AOI222 de los multiplexores de bank_a/b del
register file. El nombre a_rdata_o corresponde a la instrucción **registrada**,
no demuestra por sí mismo un problema dentro de la ROM combinacional.

Capacitancias en max_ss:
- clknet_0_clk_i: 0,337637 pF, clkbuf_0_clk_i/clkbuf_16.
- clknet_3_6__leaf_clk_i: 0,261793 pF, clkbuf_3_6__f_clk_i/clkbuf_16.
- net385: 0,228624; net494: 0,215590; net453: 0,214345;
  net406: 0,211398; net381: 0,209264; _1548_: 0,203911;
  net389: 0,201582; net441: 0,200707 pF.

Las 58 violaciones de fanout son de CTS; las peores hojas tienen carga 18
frente a límite 10. Los problemas dominantes son internos, no puertos de
salida. Hay además 222 pines de slew asociados al reset según el analizador
anterior; no se debe atribuir todo a ROM ni solo a rs1/rs2.

La reparación post-GPL baseline insertó 718 buffers, y el propio log registra
que usó dlyb_1 para buffer_ports. No redimensionó ninguna instancia en esa
etapa. El uso de un delay buffer en un selector distribuido es una hipótesis
concreta a probar, no una garantía de reparación.

## Propuesta antes de implementar experimentos

1. E1: excluir únicamente la familia dlyb del conjunto elegible por síntesis
   y PnR mediante EXTRA_EXCLUDED_CELLS. Mantener fuente, SDC, reloj,
   utilización y CTS baseline. Objetivo: evitar que los selectores de alta
   carga sean conducidos por celdas de retardo y permitir buffers normales.
   Verificar hold, porque también se restringe el conjunto de reparación.
2. E2, solo según el resultado E1: modificar exclusivamente el tamaño de
   cluster CTS para atacar el fanout y capacitancia del reloj.
3. E3, solo según evidencia de E1/E2: una reparación localizada o post-GRT,
   sin combinar cambios independientes ni repetir barridos de márgenes.

Máximo tres candidatos físicos. Ninguno se acepta sin setup/hold en nueve
corners, revisión eléctrica y DRC/LVS/antena. Ejecutar deck KLayout externo
para cualquier candidato prometedor. No se ha declarado cierre.

## Herramientas y comandos admitidos

Docker info y hello-world respondieron correctamente desde WSL.
LibreLane instalado: 3.0.16. PDK:
`~/.ciel/gf180mcuD`, revisión
`8afc8346a57fe1ab7934ba5a6056ea8b43078e71`.
OpenROAD de la imagen: commit `dcf36133a369abc8f3c5e5738cd4d82e4903c0e0`.

La versión instalada define EXTRA_EXCLUDED_CELLS en
`librelane/config/flow.py`; `steps/openroad.py` combina la exclusión con
PNR_EXCLUDED_CELL_FILE y `scripts/openroad/common/io.tcl` aplica set_dont_use.
Esto limita las celdas elegibles; no cambia límites Liberty/SDC.
CTS_SINK_CLUSTERING_SIZE y RUN_POST_GRT_DESIGN_REPAIR también existen.
La evidencia de ayuda real se guardará en `reports/stage12/tool_help.log`.

Fuentes oficiales consultadas:
- https://github.com/The-OpenROAD-Project/OpenROAD/blob/master/src/rsz/README.md
- https://librelane.readthedocs.io/en/latest/reference/step_config_vars.html

Las opciones de la documentación latest se contrastan con el código y ayuda
de la instalación; no se asume que todas existan en esta revisión.

## Resultados

### Trazabilidad del diagnóstico baseline

El script nuevo `scripts/stage12_audit.py` cruza cada pin del reporte con
su red, driver y todos los pines de carga en el netlist. Guarda el reporte
fuente y número de línea de cada incumplimiento. No suma nueve veces los
conteos de un mismo circuito: conserva las métricas por corner.

Evidencia: `reports/stage12/etapa9_rom_ram_util40_debounce/`:
`violations.json`, `nets.json`, `corners.csv`, `summary.json`.

| Red | Pines con slew violado | Transición máx. (ns) | Slack eléctrico (ns) | Driver |
|---|---:|---:|---:|---|
| net385 | 11 | 6,292998 | -3,292998 | fanout385/Z, dlyb_1 |
| net494 | 11 | 5,939054 | -2,939054 | fanout494/Z, dlyb_1 |
| net453 | 11 | 5,908012 | -2,908013 | fanout453/Z, dlyb_1 |
| net406 | 11 | 5,825825 | -2,825825 | fanout406/Z, dlyb_1 |
| net389 | 11 | 5,555351 | -2,555351 | fanout389/Z, dlyb_1 |
| net441 | 11 | 5,534668 | -2,534668 | fanout441/Z, dlyb_1 |
| net445 | 11 | 5,481779 | -2,481779 | fanout445/Z, dlyb_1 |
| net461 | 11 | 5,472543 | -2,472543 | fanout461/Z, dlyb_1 |
| net515 | 11 | 5,436253 | -2,436253 | fanout515/Z, dlyb_1 |
| net525 | 11 | 5,423307 | -2,423307 | fanout525/Z, dlyb_1 |

Los 11 pines incluyen el driver y receptores; no deben confundirse con
11 cargas de fanout. Por ejemplo net385 conduce diez receptores:
_5413_/B1, _5437_/B1, _5500_/B1, _5527_/B1, _5591_/A2,
_5600_/B1, _5611_/A2, _5626_/B1, _5634_/A2 y _5689_/B1.
Son entradas AOI22_1/AOI222_1 sobre datos de bank_a[7].
Las listas completas para las demás redes están en nets.json.
Además, ordenar por severidad absoluta, en lugar de cantidad de pines,
produce la tabla siguiente. Todas las líneas remiten al checks.rpt original
de max_ss, no al resumen de una etapa anterior.

| Red | Driver (tipo) | Transición máx. (ns) | Exceso (ns) | Línea |
|---|---|---:|---:|---:|
| _3521_ | _7139_/ZN (aoi211_1) | 6,518591 | 3,518591 | 234 |
| net385 | fanout385/Z (dlyb_1) | 6,292998 | 3,292998 | 238 |
| _1913_ | _5363_/ZN (nor2_1) | 6,221088 | 3,221088 | 248 |
| _1916_ | _5366_/ZN (nor2_1) | 6,006538 | 3,006539 | 254 |
| _1904_ | _5354_/ZN (nor2_1) | 5,997386 | 2,997386 | 259 |
| _1573_ | _4991_/ZN (nor2_1) | 5,943064 | 2,943064 | 264 |
| net494 | fanout494/Z (dlyb_1) | 5,939054 | 2,939054 | 270 |
| net453 | fanout453/Z (dlyb_1) | 5,908012 | 2,908013 | 281 |
| net406 | fanout406/Z (dlyb_1) | 5,825825 | 2,825825 | 292 |
| _1907_ | _5357_/ZN (nor2_1) | 5,730163 | 2,730163 | 303 |

La peor transición **global** baseline es por tanto 6,518591 ns, no
6,292998 ns (valor de la red con mayor cantidad de pines afectados).
Los dos criterios no deben confundirse. La relectura independiente del
netlist+SDC+SPEF confirma 6,518591 ns, setup WS 37,171986 ns y hold WS
0,941919 ns en max_ss, coherentes con los originales a precisión de reporte.

La asignación de rs1/rs2 se verifica en
`rtl/espino_core/espino_id_stage.v:56–57`; el registro de instrucción,
en `rtl/pochoco_memory_rom_ram.v:30`.

### E1: exclusión dlyb

Configuración: `asic/rom_ram_stage12_no_dlyb.json`.
Corrida nueva: `etapa12_rom_ram_no_dlyb`.
El cambio de configuración es únicamente EXTRA_EXCLUDED_CELLS.
El netlist sintetizado es idéntico a la baseline al normalizar solo el
prefijo jerárquico u_core.genblk1.g_asic_regfile, introducido previamente
por la selección de Etapa 10. SHA-256 normalizado:
`191a9d4a5730278d810eb0ce77ac5f17b0a820e51bbf9eaa52d7be887c505163`.
No se alteró RTL, programa ni latencia. Área sintetizada 139472,032 µm² y
874 FF, iguales a la baseline.

Observación durante post-GPL: OpenROAD elige dlyc_1 al excluir dlyb_1
(log de reparación, líneas 34–35), por lo que todavía no se ha conseguido
forzar buffers convencionales. Este dato motivará evaluar la exclusión de
la familia completa de celdas delay si los resultados post-route lo confirman.
No es un ajuste de margen ni una relajación de restricciones.

E1 terminó el flujo completo con DRC de routing=0, Magic DRC=0, LVS=0 y
antena=0. No se ejecutó KLayout externo sobre E1 porque no se recomienda:
solo elimina 102 slews y su peor capacitancia (0,338253 pF) y peor fanout
(19) son más graves que la baseline (0,337637 pF y 18). También incrementa
área y reduce el margen setup. Se descarta como candidata final.

### E2 terminado: exclusión de todas las celdas delay

E2 terminó el flujo completo con routing DRC/Magic DRC/LVS/antena=0.
Su peor slew es 6,175589 ns en net385, ahora conducida por buf_1. Por tanto,
la sustitución de delay por buf no basta para corregir la carga real en SS.
Las capacitancias residuales son clknet_0_clk_i (0,330995 pF), net385
(0,224403 pF), clknet_3_6__leaf_clk_i (0,223012 pF) y net497 (0,206777 pF).
La peor carga fanout es 17. Área stdcell 166407 µm² y utilización 47,9475 %.
Su síntesis también es idéntica a la baseline tras normalizar exclusivamente
el prefijo jerárquico ya descrito. No se modificó el comportamiento RTL.

| Caso | Slew / cap / fanout | Peor slew (ns) | Peor cap (pF) | Peor fanout | Stdcell (µm²) | Die (mm²) | Utilización real |
|---|---:|---:|---:|---:|---:|---:|---:|
| Baseline Etapa 9 | 2695 / 10 / 58 | 6,518591 | 0,337637 | 18 | 181227 | 0,375554 | 52,2176 % |
| E1: sin dlyb | 2593 / 7 / 57 | 6,364203 | 0,338253 | 19 | 194403 | 0,375554 | 56,0139 % |
| E2: sin dly* | 2508 / 4 / 57 | 6,175589 | 0,330995 | 17 | 166407 | 0,375554 | 47,9475 % |
| E3: sin dly*, resizer SS | 440 / 2 / 57 | 5,405243 | 0,336702 | 19 | 177912 | 0,375554 | 51,2625 % |

Los conteos son el máximo entre nueve corners, no su suma. Se muestra además
la magnitud de los incumplimientos: un conteo menor no implica mejor severidad.

| Caso | Peor setup WS (ns) | Peor hold WS (ns) | Setup WNS / TNS (ns) | Hold WNS / TNS (ns) |
|---|---:|---:|---:|---:|
| Baseline | +37,171987 | +0,126038 | 0 / 0 | 0 / 0 |
| E1 | +21,993913 | +0,127934 | 0 / 0 | 0 / 0 |
| E2 | +50,780487 | +0,116683 | 0 / 0 | 0 / 0 |
| E3 | +53,646852 | +0,054793 | 0 / 0 | 0 / 0 |

Todos los WNS/TNS anteriores son cero en cada uno de los nueve corners.
WS es el peor slack real positivo; WNS se trunca a cero sin slack negativo.
Evidencia numérica completa por corner: reports/stage12/timing_nine_corners.csv.

| Caso | Uso global GRT | Overflow H / V / total | Cable global (µm) | Cable final (µm) |
|---|---:|---:|---:|---:|
| Baseline | 24,38 % | 0 / 0 / 0 | 536802 | 392042 |
| E1 | 24,61 % | 0 / 0 / 0 | 542984 | 387773 |
| E2 | 24,13 % | 0 / 0 / 0 | 529972 | 380885 |
| E3 | 24,60 % | 0 / 0 / 0 | 543270 | 387934 |

Fuente de uso/overflow: 39-openroad-globalrouting/openroad-globalrouting.log
de cada corrida. Cables/áreas: final/metrics.json.

### Decisión E2 antes de implementar

El STA post-route E1 ya terminó en nueve corners: 2593/7/57 violaciones de
slew/cap/fanout; setup WS mínimo 21,993913 ns y hold WS mínimo 0,127934 ns,
TNS=0. Área stdcell 194403 µm², utilización 56,0139 %. DRC/LVS/signoff físico
todavía se están ejecutando al decidir E2; estos datos no implican cierre.

El log post-GPL confirma que se reemplazó dlyb por dlyc, no por buf. Por ello
E2 amplía solamente EXTRA_EXCLUDED_CELLS de dlyb_* a dly*. La variable
principal sigue siendo el conjunto de celdas delay elegibles. No cambia CTS,
márgenes, utilización ni límites. Objetivo: comprobar buffers convencionales
antes de atribuir el residual a arquitectura o aumentar buffers indiscriminadamente.

### Propuesta de reloj preparada, condicionada al resultado E2 (no ejecutada)

El inventario de solo lectura sobre el ODB post-CTS de E2 identifica 67
redes de reloj con más de cuatro cargas, máximo 17 cargas físicas. Dividirlas
en grupos de hasta cuatro receptores requiere 265 buffers (estimación exacta
del inventario, no resultado final); evidencia: reports/stage12/clock_plan_e2.log.
La STA intermedia E2 tiene 0 slew, 1 cap y 57 fanout; aún falta STA post-route.

Si el resultado post-route confirma que el residual dominante es CTS, el
tercer y último experimento añadirá un único paso de distribución dirigida
de cargas después de CTS. Mantendrá todas las opciones E2 y dividirá cada
red clknet_* de más de cuatro receptores en grupos geográficos de hasta
cuatro, mediante insert_buffer con clkbuf_4. No se alteran celdas lógicas,
RTL, SDC ni márgenes del resizer. Se pretende limitar tanto el fanout como
la capacitancia de ramas y raíz; no se asume que modificar solo el tamaño
de cluster CTS repare la raíz (ya quedó una raíz violada en Etapa 6B).

El comando insert_buffer y sus opciones buffer_cell, load_pins, location,
buffer_name y net_name existen en la ayuda de esta instalación. Se integrará
el paso con la API Python de LibreLane y se conservará el resto de Classic,
incluyendo reparación de timing, routing, extracción y todos los checkers.
El paso propuesto se ejecutaría una vez y tendría un límite explícito de 400 buffers.
Después se comprobarán los nueve corners; insertar clock buffers puede
cambiar skew/hold y no se acepta sin las verificaciones completas.

### Decisión del tercer y último experimento: reparación con modelo SS

La condición anterior no se cumplió: E2 post-route conserva 2508 slews,
4 caps y 57 fanouts. En max_ss, net385 alcanza 6,175589 ns y 0,224403 pF.
La STA intermedia nominal sin slews no demuestra cierre en SS. El peor
setup E2 es +50,780487 ns; hold +0,116683 ns, TNS=0, nueve corners.

Se descarta usar el último experimento solo para CTS mientras persisten
miles de slews de datos. El cambio E3 será **únicamente RSZ_CORNERS** a
[max_ss_125C_4v50], conservando la exclusión dly* y todo lo demás de E2.
Es una opción real (steps/common_variables.py:455–457); ResizerStep pasa
esa lista a la carga de bibliotecas (steps/openroad.py:2397).

Los logs de reparación anteriores cargan nueve corners con bibliotecas PVT
repetidas (STA-1140); read_pnr_libs enumera corners mediante un array Tcl.
Se probará si reparar exclusivamente con SS evita una selección inadecuada
del modelo en los cálculos de transición/sizing. Esto es una hipótesis,
no un fallo de OpenROAD demostrado. No se relajan los 3 ns / 0,2 pF / 10,
ni se cambian STA_CORNERS ni TIMING_VIOLATION_CORNERS: el signoff continúa
en nueve corners. El cambio puede perjudicar hold en FF y debe comprobarse.

La implementación de distribución de reloj queda como propuesta no usada:
scripts/stage12_clock_flow.py y stage12_clock_split.tcl, con ayuda validada
en reports/stage12/clock_flow_help_v2.log. El inventario fue de solo lectura;
no cuenta como experimento físico ni cambió ninguna corrida. No se lanzará
un cuarto candidato.

## E3: resultado completo y comparación final

Única diferencia frente a E2: `RSZ_CORNERS=["max_ss_125C_4v50"]`.
El flujo Classic termina con código 0, pero ese código **no significa cierre**:
sus checkers informan las violaciones eléctricas pendientes.

En post-GPL, E3 redimensiona 75 instancias y añade 1316 buffers, frente a
0 redimensionamientos y 721 buffers en E2. Área post-GPL 172582,23 µm²;
área stdcell final 177912 µm², por debajo de los 181227 µm² baseline.
No se ejecutó un barrido de márgenes ni se añadió el paso propuesto de reloj.
La ocupación real 51,2625 % y overflow GRT=0 verifican que el aumento de
buffering no provocó saturación de utilización en esta corrida.

Esta comparación demuestra que seleccionar explícitamente SS para reparación
es relevante. No demuestra por sí sola un bug universal de OpenROAD ni que
STA-1140 sea la causa única: se conservan la carga distribuida, las estimaciones
pre-route y el CTS como causas separadas.

### Timing y controles eléctricos de E3 por corner

Fuente: `asic/runs/etapa12_rom_ram_no_delay_ss/final/metrics.json` y
`55-openroad-stapostpnr/<corner>/{checks,ws.max,ws.min,wns.max,wns.min,tns.max,tns.min}.rpt`.
**Setup WNS=0, setup TNS=0, hold WNS=0 y hold TNS=0 en cada fila**, en ns.

| Corner | Setup WS (ns) | Hold WS (ns) | Slew | Cap | Fanout |
|---|---:|---:|---:|---:|---:|
| nom_tt_025C_5v00 | +73,493064 | +0,255601 | 0 | 2 | 57 |
| nom_ss_125C_4v50 | +55,589675 | +0,725120 | 221 | 2 | 57 |
| nom_ff_n40C_5v50 | +75,739559 | +0,055280 | 0 | 2 | 57 |
| min_tt_025C_5v00 | +73,603220 | +0,254901 | 0 | 2 | 57 |
| min_ss_125C_4v50 | +57,212395 | +0,724056 | 149 | 2 | 57 |
| min_ff_n40C_5v50 | +75,813846 | +0,054793 | 0 | 2 | 57 |
| max_tt_025C_5v00 | +73,361422 | +0,256437 | 21 | 2 | 57 |
| max_ss_125C_4v50 | +53,646852 | +0,726384 | 440 | 2 | 57 |
| max_ff_n40C_5v50 | +75,650954 | +0,055865 | 0 | 2 | 57 |

Se conserva además una relectura independiente del netlist, SDC y SPEF,
incluyendo el peor pin aunque no viole su límite:
`reports/stage12/etapa12_rom_ram_no_delay_ss/worst_<corner>.rpt` y
`independent_worst.json`.
Su comparación auxiliar admite 0,001 ns (1 ps) de diferencia numérica entre
la exportación netlist/SPEF y los reportes originales. La diferencia observada
es menor a 0,0001 ns. **Esta tolerancia no es una restricción de signoff**:
no se usa para aprobar slacks negativos ni se modifica la SDC/Liberty.
Las tablas anteriores mantienen los valores oficiales, no los de la relectura.
La primera comprobación auxiliar abortó al usar una tolerancia demasiado
estricta de 0,00002 ns; los reportes se preservaron y se reutilizaron sin
sobrescribirlos al completar la comparación.

En FF se observan límites Liberty efectivos de slew de 2,6 ns en ciertos
pines, más estrictos que el máximo global SDC de 3 ns. No se alteró ninguno.

### Incumplimientos restantes y severidad

En max_ss, todos los incumplimientos siguen siendo internos.

| Red / pin | Driver | Incumplimiento real | Evidencia en checks.rpt max_ss |
|---|---|---|---|
| _1548_, _5285_/A1 | _4966_/Z, or2_1 | Slew 5,405243 ns; límite 3; slack -2,405243 ns | línea 258 |
| net860 | fanout860/Z, buf_1 | Slew 5,158673 ns; slack -2,158673 ns | línea 268 |
| data_wdata[4] | _9249_/Q, dffrnq_1 | Slew 4,678382 ns; slack -1,678382 ns | línea 279 |
| net1237 | fanout1237/Z, buf_1 | Slew 4,583680 ns; slack -1,583680 ns | línea 287 |
| net804 | fanout804/Z, buf_1 | Slew 4,190093 ns; slack -1,190092 ns | línea 294 |
| clknet_0_clk_i | clkbuf_0_clk_i/Z, clkbuf_16 | Cap 0,336702 pF; límite 0,2; slack -0,136702 pF | línea 765 |
| clknet_3_6__leaf_clk_i | clkbuf_3_6__f_clk_i/Z, clkbuf_16 | Cap 0,234354 pF; slack -0,034354 pF | línea 766 |

Las peores hojas de clock, entre ellas `clknet_leaf_36_clk_i` y
`clknet_leaf_38_clk_i`, tienen fanout 19 con límite 10: slack -9.
Las 57 violaciones de fanout y las dos de capacitancia son de CTS.
Esto empeora la severidad máxima de fanout frente a baseline (18) y E2 (17),
aunque el conteo baja de 58 a 57 respecto de baseline.

La conexión real de _4966_ contiene instrucción registrada [21] y la
decodificación de [22:23], señales rs2, y alimenta el cono del register file.
Se verifica en `final/nl/asic_top.nl.v:23415` y receptores como
`_5285_/A1` en la línea 24908. net860 procede de bits [16:18], rs1.
Los listados completos de drivers y cargas están en `nets.json`; no se
atribuyen estas violaciones automáticamente a la ROM combinacional.

Clasificación auxiliar de los 440 pines de slew, con direcciones de pines
extraídas de la Liberty real (clasificación topológica, no área jerárquica):

| Raíces o cono identificado | Pines |
|---|---:|
| Instrucción/fetch | 193 |
| Memoria de datos | 38 |
| Reset | 13 |
| Cono mixto instrucción/datos/register file/periféricos | 45 |
| Otra lógica combinacional o trazado sin raíz identificada | 112 |
| Cono mixto instrucción/datos/register file | 37 |
| Cono mixto instrucción/register file | 2 |
| Total | 440 |

### Corrección del analizador auxiliar

Se detectó que `scripts/analyze_electrical.py` usa una lista global que
incluye S como supuesto pin de salida. En `mux2_2`, S es **entrada**.
Eso podía inventar drivers adicionales y distorsionar la clasificación de
conos (por ejemplo net943), pero **no afecta los conteos oficiales de STA**.

No se reescribieron análisis históricos ni el script anterior. El analizador
nuevo `scripts/stage12_audit.py` usa la dirección real de cada pin de cada
celda, extraída de las 229 celdas Liberty por
`scripts/stage12_pin_directions.py`.
Fuente, SHA-256 y tabla están en `reports/stage12/cell_pin_directions.json`.
Las evidencias autoritativas de Etapa 12 son `nets.json`, `violations.json`
y `summary.json`, regeneradas con esa corrección.
El `classified.json` auxiliar inicial conserva la clasificación anterior
y **no debe usarse para atribuir drivers ni módulos**.
Las tablas de este documento usan el analizador corregido.

## Signoff ejecutado

| Control | E1 | E2 | E3 (mejor candidato) |
|---|---|---|---|
| Flujo Classic completo | Sí | Sí | Sí |
| Setup/hold en nueve corners | WNS/TNS=0 | WNS/TNS=0 | WNS/TNS=0 |
| Routing DRC | 0 | 0 | 0 |
| Magic DRC | 0 | 0 | 0 |
| LVS | 0 | 0 | 0 |
| Antena, redes/pines | 0/0 | 0/0 | 0/0 |
| XOR Magic/KLayout | 0 | 0 | 0 |
| KLayout DRC integrado | Omitido | Omitido | Omitido |
| KLayout DRC externo de Etapa 9 | No ejecutado | No ejecutado | Limpio |
| Cierre eléctrico | No | No | No |
| GDSII definitivo | No | No | No |

El DRC de routing E3 evolucionó 2095 → 816 → 717 → 7 → 0. No se confunde
GRT overflow=0 con DRC detallado=0. Magic informa COUNT:0 y Netgen termina
con `Final result: Circuits match uniquely.`.
El checker KLayout integrado permanece sin runset configurado; el resultado
limpio corresponde a la **ejecución externa real**, no a ese checker omitido.

KLayout externo, mismo script/deck de Etapa 9, variante D, modo deep:
- `reports/stage12/klayout_no_delay_ss/drc_run_2026_10_25_19_02_23.log`.
- `reports/stage12/klayout_no_delay_ss_console.log:5884`:
  `Klayout DRC run is clean. GDS has no DRC violations.`.
- Reportes originales de reglas `*.lyrdb` y plantillas en la misma carpeta.

Se comprobaron además los 41 reportes XML `.lyrdb` generados: cero elementos
de violación en total. La invocación externa terminó con código de salida 0.

GDSII candidato:
`asic/runs/etapa12_rom_ram_no_delay_ss/final/gds/asic_top.gds`.
SHA-256:
`bd78dab33b34b2773eadc4ea550e48b38a0a63bdac12bce0aa2a854b97e9fa7b`.
Fue el archivo revisado por KLayout externo. No es un GDSII con signoff completo.

## Validación funcional y preservación

No se modificó RTL ni Assembly, ni se activó el register file particionado.
Las tres configuraciones tienen exactamente la misma lista de fuentes y
MemoryArchitecture=1. Mantienen la ALU baseline y el programa ASIC original.

Los tres netlists sintetizados son textualmente idénticos a la baseline
después de normalizar **solo** el prefijo jerárquico existente
`u_core.genblk1.g_asic_regfile → u_core.g_asic_regfile`.
El SHA-256 normalizado es
`191a9d4a5730278d810eb0ce77ac5f17b0a820e51bbf9eaa52d7be887c505163`.
Conservan área sintetizada 139472,032 µm² y 874 FF.
Evidencia: `synthesis_identity` de cada `summary.json`.

El hash de `sw/game.s` se mantuvo:
`f80a526f10252884f20d90bf5b411668edee74f52d71524321822320909cc6c3`.
Los manifiestos de lanzamiento registran además el hash de la ROM incorporada.

No se repitieron las 16 pruebas Python ni las simulaciones RTL/post-síntesis
en esta etapa: no hubo modificación RTL que active ese requisito condicional.
No se presenta la equivalencia previa de Etapa 7 como una prueba ejecutada
nuevamente. La identidad del sintetizado demuestra conservación de su lógica;
la reparación física añade/sustituye buffers/celdas y se revisó con STA, DRC
y LVS. No se ejecutó simulación temporal SDF ni equivalencia formal post-route.

El informe LaTeX y su ZIP permanecieron sin modificar. Ninguna corrida anterior
se borró o reemplazó.

## Comandos reproducibles y evidencias

Ejecutar desde WSL en el alias bind existente `/tmp/pochoco3`, cuya ubicación
real fue verificada con `findmnt -T /tmp/pochoco3`.
No trasladar ni reemplazar el proyecto; el alias evita el problema ABC con
espacios en la ruta Windows documentado en etapas anteriores.

Los comandos originales fueron:

~~~sh
cd /tmp/pochoco3

python3 scripts/stage12_run.py asic/rom_ram_stage12_no_dlyb.json \
  --tag etapa12_rom_ram_no_dlyb
python3 scripts/stage12_run.py asic/rom_ram_stage12_no_delay.json \
  --tag etapa12_rom_ram_no_delay
python3 scripts/stage12_run.py asic/rom_ram_stage12_no_delay_ss.json \
  --tag etapa12_rom_ram_no_delay_ss
~~~

El launcher se niega a sobrescribir una corrida o log existente. Para reproducir,
usar tags nuevos, por ejemplo `etapa12_repro_no_delay_ss`. Mantener el mismo
entorno PDK y versión de imagen. Se conserva el comando efectivo en
`reports/stage12/<tag>_manifest.json`.

Análisis, sin alterar hardware:

~~~sh
python3 scripts/stage12_pin_directions.py \
  "$HOME/.ciel/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/lib/gf180mcu_fd_sc_mcu7t5v0__tt_025C_5v00.lib" \
  --output reports/stage12/cell_pin_directions.json

python3 scripts/stage12_audit.py etapa12_rom_ram_no_delay_ss
python3 scripts/stage12_summarize.py
python3 scripts/stage12_measure.py etapa12_rom_ram_no_delay_ss --jobs 1 --reuse-existing

sh scripts/run_klayout_drc.sh \
  asic/runs/etapa12_rom_ram_no_delay_ss/final/gds/asic_top.gds \
  reports/stage12/klayout_no_delay_ss
~~~

Para repetir KLayout, usar un directorio de salida nuevo; el anterior contiene
los reportes originales. `stage12_summarize.py` consolida los tres tags
originales fijos y la baseline; un tag de reproducción se analiza individualmente
con `stage12_audit.py`.

Evidencias:
- `asic/runs/etapa12_rom_ram_{no_dlyb,no_delay,no_delay_ss}/`: corridas completas.
- `reports/stage12/<tag>.log`: salida original del launcher.
- `reports/stage12/<tag>_manifest.json`: comandos y hashes.
- `reports/stage12/<tag>/{corners.csv,nets.json,violations.json,summary.json}`.
- `reports/stage12/{comparison.csv,comparison.json,timing_nine_corners.csv}`.
- `reports/stage12/etapa12_rom_ram_no_delay_ss/independent_worst.json` y `worst_*.rpt`.
- `reports/stage12/tool_help.log`: ayuda real; size_cell no existe con ese nombre.
- `reports/stage12/klayout_no_delay_ss/`: DRC externo.
- Los sondeos auxiliares iniciales de STA se preservan en
  `reports/stage12/etapa9_rom_ram_util40_debounce/all_electrical_max_ss*.rpt`;
  los primeros fallaron por sintaxis/carga LEF, y v4 reproduce el resultado.
  Fueron lecturas de diagnóstico, no configuraciones físicas adicionales.

## Conclusión y siguiente intervención justificada

E3 elimina 2255 de 2695 slews (83,67 %), los ocho incumplimientos de
capacitancia de datos y una violación de fanout en conteo. Reduce área stdcell
en 3315 µm² frente a baseline y mejora setup; reduce margen hold, que aún cumple.
No elimina la capacitancia de reloj ni los 57 fanouts de CTS, y deja
440 slews, principalmente de decodificación/instrucción y otros conos.
La severidad máxima de fanout empeora a 19. No se declara cierre ni se acepta
una excepción implícita.

La siguiente intervención debe separar dos causas que siguen demostradas:
1. Reparar **después de global routing** con el modelo SS, dirigiendo
   sizing/distribución de cargas a _4966_/or2_1 (_1548_), fanout860/buf_1,
   _9249_/dffrnq_1 y las redes del listado residual; usar RC de routing,
   no suponer que otra exclusión de familias arreglará el problema.
2. En una prueba independiente, redistribuir las cargas de raíz/ramas CTS
   responsables de 0,336702/0,234354 pF y de fanout 19. El inventario y paso
   acotado de reloj están preparados, pero el paso **no fue ejecutado ni
   validado físicamente** en esta etapa. No puede prometerse que cierre,
   especialmente con el menor margen hold observado.

Se agotó el máximo autorizado de tres experimentos. No se lanzó un cuarto.
Se preservan E3 como mejor candidata y Etapa 9 como referencia histórica
reglamentaria, ambas con el estado eléctrico real explícito.


