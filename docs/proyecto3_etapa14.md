# Proyecto 3 — Etapa 14: diagnóstico profundo y ECO eléctrico

Fecha: 26 de octubre de 2026 (America/Santiago).

## Conclusión ejecutiva

No se consiguió cierre eléctrico completo. Se conservaron sin modificar las
corridas de Etapas 9, 12 y 13. La mejor candidata física sigue siendo
`etapa12_rom_ram_no_delay_ss` por su balance de área, slew y hold:

| Corrida | Slew | Capacitancia | Fanout | Setup WS mínimo (ns) | Hold WS mínimo (ns) | Estado |
|---|---:|---:|---:|---:|---:|---|
| Etapa 9 reglamentaria | 2695 | 10 | 58 | +37,171987 | +0,126038 | Sin cierre eléctrico |
| Etapa 12 SS | 440 | 2 | 57 | +53,646852 | +0,054793 | Mejor candidata |
| Etapa 13 post-GRT | 410 | 3 | 57 | +53,159008 | +0,054793 | Experimental |
| Etapa 13 CTS | 468 | 1 | 0 | +52,430605 | +0,010418 | Experimental |
| Etapa 14 ECO post-route | No comparable | No comparable | No comparable | +52,30 observado | +0,65 observado | Descartado |

Las tres corridas físicas anteriores completas tienen WNS/TNS de setup y
hold igual a 0/0 en los nueve corners, Routing DRC, Magic DRC, LVS y antena
sin errores. KLayout DRC externo está limpio para Etapa 9 y Etapa 12; no se
ejecutó sobre la variante CTS de Etapa 13 porque aún tenía violaciones
eléctricas. Ningún GDSII es definitivo.

## 1. Evidencia leída

Se leyó íntegramente `docs/proyecto3_etapa12.md` (562 líneas) y
`docs/proyecto3_etapa13.md` (279 líneas). Las fuentes primarias revisadas
fueron:

- `asic/runs/etapa9_rom_ram_util40_debounce/`;
- `asic/runs/etapa12_rom_ram_no_delay_ss/`;
- `asic/runs/etapa13_rom_ram_postgrt/`;
- `asic/runs/etapa13_rom_ram_cts_retry/`;
- `reports/stage12/etapa12_rom_ram_no_delay_ss/`;
- `reports/stage13/baseline_residual_pins.csv`;
- `reports/stage13/etapa13_rom_ram_cts_retry/corners.csv`;
- `final/metrics.json`, `final/sdc/asic_top.sdc`,
  `final/nl/asic_top.nl.v`, DEF, ODB y los nueve reportes
  `55-openroad-stapostpnr/<corner>/checks.rpt`.

Los límites no se cambiaron: `set_max_transition 3.0000`,
`set_max_capacitance 0.2000` y `set_max_fanout 10.0000` en la SDC generada.
La interfaz sigue usando la SDC genérica de LibreLane, sin
`PNR_SDC_FILE` ni `SIGNOFF_SDC_FILE` específicos.

## 2. Causas raíz

### Datos e instrucción registrada

En la mejor candidata, el corner `max_ss_125C_4v50` concentra 440 slews,
dos capacitancias y 57 fanouts. `reports/stage13/baseline_residual_pins.csv`
clasifica 193 pines como instrucción/ROM/fetch, 38 como memoria de datos,
13 como reset, 112 como combinacionales y 84 con raíces mixtas. Esta
clasificación topológica no permite atribuir todos los pines a la ROM
combinacional.

Las redes más relevantes son:

| Red | Driver | Celda | Cargas | Slew máx. (ns) | Límite | Capacidad |
|---|---|---|---:|---:|---:|---:|
| `_1548_` | `_4966_/Z` | `or2_1` | 9 | 5,405243 en Etapa 12; 5,536282 en CTS | 3 | 0,201080 pF en CTS |
| `net860` | `fanout860/Z` | `buf_1` | 10 | 5,158673 en Etapa 12; 5,491123 en CTS | 3 | residual de datos |
| `data_wdata[4]` | `_9249_/Q` | `dffrnq_1` | según CSV | 4,678382 | 3 | residual |
| `net1237` | `fanout1237/Z` | `buf_1` | según CSV | 4,583680 | 3 | residual |
| `net804` | `fanout804/Z` | `buf_1` | según CSV | 4,190093 | 3 | residual |
| `_3503_` | `_7118_/ZN` | `aoi221_2` | según CSV | 4,007598 | 3 | residual |

`_1548_` tiene diez pines reportados, nueve receptores `and4_1` y el propio
driver. Sus raíces corresponden a `a_rdata_o[21:23]`, es decir, lógica de
fetch posterior al registro de instrucción. `net860` tiene diez cargas
reportadas y está conducida por `buf_1`; ambas redes están separadas
físicamente por decenas o más de cien micrómetros. `rs1` y `rs2` se forman
desde la instrucción registrada en `rtl/espino_core/espino_id_stage.v:56–57`;
el registro de instrucción está en `rtl/pochoco_memory_rom_ram.v:30`.
Por ello el problema no es exclusivamente el `case` de `game_rom.v`.

### Reloj

La variante CTS de Etapa 13 dejó fanout cero, pero el baseline de Etapa 12
tenía 57 hojas CTS con cargas de hasta 19 frente a límite 10. Las redes
`clknet_0_clk_i` y `clknet_3_6__leaf_clk_i` tenían, antes del CTS dirigido,
0,336702 pF y 0,234354 pF frente a 0,2 pF. Son raíz y rama intermedia del
árbol; no son cargas originadas en la ROM. El CTS insertó 265 `clkbuf_4`,
subió el área a 186061 µm² y redujo el hold mínimo a +0,010418 ns.

### Reset y puertos

El análisis de los reportes no encontró las violaciones eléctricas principales
en puertos externos. La auditoría previa contabilizó 13 pines clasificados
como reset en la candidata; los 440 incumplimientos corresponden a pines
internos. Esto no constituye una especificación física real de pads: las
cargas y delays de interfaz son hipótesis genéricas de LibreLane.

## 3. Por qué post-GRT y post-route difieren

El paso `OpenROAD.RepairDesignPostGRT` de la Etapa 13:

~~~text
repair_design -verbose -max_wire_length 0.0 -slew_margin 10.0 -cap_margin 10.0
[INFO RSZ-0034] Found 1 slew violations.
[INFO RSZ-0039] Resized 1 instances.
~~~

Opera después de global routing, con parasíticos estimados de GRT. En cambio,
el STA final de `55-openroad-stapostpnr` lee el SPEF extraído después de
detailed routing, y el conteo del corner SS es 468 slews, una capacitancia
y cero fanouts. Las entradas no son equivalentes:

| Medición | Parásitos | Etapa física | Resultado CTS |
|---|---|---|---|
| `repair_design` post-GRT | Estimación global | Antes de detailed routing | 1 slew detectado |
| `checks.rpt` post-route | SPEF RC extraído | Después de detailed routing y RCX | 468 slews, 1 cap, 0 fanout |

El log de post-GRT también registra las restricciones genéricas, pero la
estimación GRT no modela las longitudes, acoplamientos y cargas exactas que
aparecen en el SPEF. Por eso el resultado post-GRT no puede usarse como
prueba de cierre.

## 4. Comandos y opciones realmente disponibles

La ayuda conservada en `reports/stage12/tool_help.log` corresponde a
OpenROAD commit `dcf36133a369abc8f3c5e5738cd4d82e4903c0e0`, usado por
LibreLane 3.0.16. Se comprobaron:

~~~text
repair_design [-max_wire_length] [-slew_margin] [-cap_margin]
              [-buffer_gain] [-pre_placement] [-match_cell_footprint]
insert_buffer -buffer_cell ... [-net] [-load_pins] [-location]
              [-buffer_name] [-net_name]
repair_clock_nets [-max_wire_length]
report_check_types -max_slew -max_capacitance -max_fanout -corner ...
~~~

La instalación no ofrece un comando `size_cell` con ese nombre
(\texttt{STA-0160 no commands match 'size_cell'}). LibreLane sí reconoce
`RUN_POST_GRT_DESIGN_REPAIR`, pero no existe en ese paso una reparación
post-route completa que conserve automáticamente SPEF, legalización,
detailed rerouting, RCX y todos los checkers. Un ECO posterior requeriría
relegalizar y enrutar físicamente las modificaciones, no solo cambiar el
ODB.

## 5. Experimento único de Etapa 14

Se eligió como base `etapa13_rom_ram_cts_retry`, porque ya había eliminado
el fanout y una capacitancia de reloj. Se ejecutó un único script reproducible:

~~~text
scripts/stage14_postroute_eco.tcl
~~~

El script lee una copia del ODB final CTS, la LEF GF180MCU, la Liberty
`ss_125C_4v50`, la SDC y el SPEF `final/spef/max/asic_top.max.spef`.
Genera sus resultados en:

~~~text
reports/stage14/eco_cts_postroute/
reports/stage14/eco_cts_postroute.log
~~~

No modifica `asic/runs/etapa13_rom_ram_cts_retry/`.

El ECO se lanzó con:

~~~text
repair_design -max_wire_length 0 -slew_margin 0 -cap_margin 0 -verbose
~~~

Sin embargo, OpenROAD informó inmediatamente:

~~~text
[WARNING EST-0027] no estimated parasitics. Using wire load models.
~~~

El ECO redimensionó 76 instancias, insertó cero buffers y mostró, bajo el
modelo de wire load, 0 slews, fanout 0 y una capacitancia aún violada.
La holgura observada fue aproximadamente +52,30 ns setup y +0,65 ns hold.
Estos números **no son post-route**: el comando no utilizó el SPEF para la
reparación, y el script no ejecutó detailed placement, detailed routing,
RCX, STA final, DRC, LVS ni antena. Los ODB, DEF y netlist generados son
artefactos exploratorios y no candidatos de signoff.

| Estado del ECO exploratorio | Resultado |
|---|---|
| Instancias redimensionadas | 76 |
| Buffers insertados | 0 |
| Violaciones que reportó el ECO | 0 slew, 1 capacitancia, 0 fanout |
| Modelo de parasíticos | Wire load; advertencia `EST-0027` |
| Detailed routing / RCX | No ejecutado |
| DRC / LVS / antena / KLayout | No ejecutados |
| Candidatura | Descartada; no comparable con post-route |

La advertencia demuestra que una llamada aislada a `repair_design` sobre un
ODB con SPEF leído no constituye un ECO post-route verificable. Continuar
con un segundo experimento habría ocultado la diferencia entre el modelo de
wire load y el RC extraído, por lo que se detuvo la etapa.

## 6. Verificación integral y estado final

- **Timing:** Etapa 12 y CTS de Etapa 13 cumplen WNS/TNS 0/0 de setup y
  hold en nueve corners, con holguras reales positivas. El ECO aislado no
  tiene STA post-route válido.
- **Slew/capacitancia/fanout:** ninguna corrida física completa alcanza
  cero en las tres clases. La CTS alcanza fanout 0, pero deja 468 slews y
  una capacitancia.
- **Routing DRC, Magic DRC, LVS y antena:** cero en las corridas completas
  documentadas; no se ejecutaron para el ECO exploratorio.
- **KLayout DRC externo:** limpio en Etapa 9 y Etapa 12; no ejecutado para
  CTS ni para ECO.
- **Funcionalidad:** no se modificó RTL, `game.s` ni el netlist sintetizado
  funcional; no se requiere repetir las 16 pruebas por este ECO de
  diagnóstico. La equivalencia post-síntesis previa permanece en
  `tests/stage7/evidence/comparison.txt` con `exact_match=true`.
- **GDSII:** los GDS de Etapas 9, 12 y 13 son candidatos; el ECO no generó
  GDSII físico validado.

## 7. Siguiente intervención técnicamente justificada

El siguiente intento debería implementarse dentro de un flujo OpenROAD/Efabless
que soporte ECO post-route real: seleccionar `_1548_`, `net860` y las redes
de datos con mayor exceso usando `report_check_types`, sustituir únicamente
los drivers débiles o insertar buffers con `insert_buffer`, relegalizar,
hacer detailed reroute y volver a extraer SPEF antes de medir. La reparación
CTS debe permanecer separada para proteger el margen hold de +0,010418 ns.
Cada cambio debe repetir los nueve corners, DRC, Magic DRC, KLayout externo,
LVS, antena y simulación funcional. No basta con redimensionar sobre wire
load ni con cambiar márgenes.

**Resultado:** no se alcanzó cierre eléctrico completo. La mejor candidata
demostrada sigue siendo `etapa12_rom_ram_no_delay_ss`; la variante CTS es
útil para demostrar la reparación del fanout, pero no sustituye la candidata
general ni puede declararse signoff.
