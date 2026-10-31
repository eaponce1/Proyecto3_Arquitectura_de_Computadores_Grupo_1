# Proyecto 3 — Etapa 9: pendientes técnicos y reproducibilidad

Fecha: 24 de octubre de 2026.

## Resultado ejecutivo

Se completaron tres pendientes de documentación y trazabilidad: el README ASIC,
el debounce dependiente de frecuencia y la evidencia de una reparación real de
antena. También se encontró y ejecutó el deck KLayout DRC distribuido con la
revisión instalada de `open_pdks`. La nueva referencia reglamentaria ROM+RAM,
100 ns y 40 % completó el flujo, cumple setup y hold en los nueve corners y
pasa routing DRC, Magic DRC, LVS, antena y XOR. **No hay cierre eléctrico**:
quedan 2695 violaciones de slew, 10 de capacitancia y 58 de fanout en el peor
corner. Por ello el GDS sigue siendo candidato, no definitivo.

Entorno usado: LibreLane 3.0.16, PDK `gf180mcuD` revisión
`8afc8346a57fe1ab7934ba5a6056ea8b43078e71`, biblioteca
`gf180mcu_fd_sc_mcu7t5v0`, Docker 29.7.2 y KLayout 0.30.7 dentro de la imagen
LibreLane.

## README y comandos reproducibles

`README.md` ahora describe la versión FPGA y el wrapper ASIC, las dos memorias,
WSL/Docker/venv, versiones exactas, generación del programa, síntesis, flujo
físico, simulación de Etapa 7, rutas de evidencia y el estado no cerrado.
Todos los targets citados existen en `Makefile`. Para la corrida reglamentaria
se añadió:

```sh
make stage9-regulatory ETAPA9_TAG=mi_corrida_rom_ram_100ns_util40
```

La variable de etiqueta evita sobrescribir resultados. El target depende de
`asic-stage4-check` y ejecuta `asic/rom_ram_util40.json`, donde constan
`CLOCK_PERIOD=100`, `FP_CORE_UTIL=40`, `MemoryArchitecture=1` y la ALU baseline.
También se añadió `stage9-klayout-drc`, respaldado por
`scripts/run_klayout_drc.sh`, y el intérprete predeterminado de los targets de
software se corrigió de `python` a `python3`, que es el ejecutable presente en
WSL. `make -B asic-rom` se ejecutó dos veces: ambas regeneraciones dieron
SHA-256 `1215d724...eaf603` para `sw/game.hex` y
`7d291767...3a7fe` para `rtl/game_rom.v`. Los comandos de software y Etapa 7
se comprobaron además mediante las pruebas reales descritas más abajo.

## Debounce

El RTL original aceptaba el vector de botones cuando el contador llegaba a
249999: son 250000 ciclos estables.

```text
FPGA: 250000 × (1 / 25 MHz) = 250000 × 40 ns  = 10 ms
ASIC anterior: 250000 × 100 ns                         = 25 ms
ASIC corregido: 100000 × 100 ns                        = 10 ms
```

Los dos flip-flops sincronizadores y la captura del candidato añaden unos pocos
ciclos antes de comenzar el conteo estable; el valor parametrizado controla la
ventana de 10 ms. Como el contador de respuesta se captura al escribir el LED
y el software observa el botón ya filtrado, el valor ASIC anterior añadía unos
15 ms artificiales a cada respuesta frente al Proyecto 2. Eso equivale a
150000 ciclos ASIC o 0,15 décimas de segundo y podía cambiar el bin de una
medición próxima a un límite de décima.

Cambios:

- `pochoco_periph` tiene `DebounceCycles=250000` por defecto.
- `pochoco_soc` propaga el parámetro.
- `asic_top` lo fija por defecto a 100000.
- `game_top` no lo sobrescribe y conserva exactamente 250000 para FPGA.
- `tests/periph_debounce_asic_tb.v` verifica un umbral parametrizado corto; la
  prueba `periph_tb` existente sigue verificando el umbral FPGA completo.

No se modificó `game.s`, su número de rondas ni la lógica del procesador.

Verificación real:

```text
python3 -B tests/run_tests.py
16 pruebas Python: PASS
core, periph FPGA, debounce parametrizado ASIC, SPI y decoder: PASS
make stage9-regulatory: elaboraciones Icarus ROM+RAM/unificada PASS; flujo completo
```

## KLayout DRC

LibreLane continúa omitiendo su paso `KLayout.DRC` porque el PDK no expone la
variable `KLAYOUT_DRC_RUNSET`. Sin embargo, la instalación real sí contiene:

```text
~/.ciel/gf180mcuD/libs.tech/klayout/drc/run_drc.py
~/.ciel/gf180mcuD/libs.tech/klayout/drc/rule_decks/main.drc
~/.ciel/gf180mcuD/libs.tech/klayout/tech/macros/gf180mcu_drc.lydrc
```

El deck está incluido en la revisión `open_pdks` instalada, identifica a
“GlobalFoundries PDK Authors”, usa licencia Apache-2.0 y documenta KLayout
0.28.4 o posterior. Para `gf180mcuD` se usó la variante D: metal superior 11K,
5LM y MIM B. No se inventaron ni editaron reglas. El alcance ejecutado fue
FEOL, BEOL y off-grid; las opciones separadas de density y antenna del script
no se habilitaron. Antena ya se verificó con OpenROAD.

La imagen LibreLane contiene KLayout 0.30.7 pero no `docopt` ni `pmap`. `docopt`
0.6.2 se instaló de forma aislada en `reports/stage9/python_deps`. Los dos
primeros intentos se preservan y fallaron exactamente con
`ModuleNotFoundError: docopt`/`pmap: command not found` y
`undefined method 'strip' for nil`. El shim `reports/stage9/bin/pmap` solo
satisface el logger informativo de memoria; no participa en ningún cálculo ni
modifica el deck.

El tercer intento sobre `etapa5_rom_ram_util40` terminó con:

```text
Klayout DRC run is clean. GDS has no DRC violations.
```

La misma ejecución se repitió sobre el GDS nuevo de Etapa 9 y también terminó
con `Klayout DRC run is clean. GDS has no DRC violations.` Sus bases `.lyrdb`
y log están en `reports/stage9/klayout_drc_etapa9_util40/`. Para repetirla sin
depender del `PATH` interactivo de Docker:

```sh
python3 -m pip install --target reports/stage9/python_deps docopt==0.6.2
make stage9-klayout-drc \
  ETAPA9_TAG=etapa9_rom_ram_util40_debounce \
  STAGE9_KLAYOUT_DIR=reports/stage9/klayout_drc_repro
```

`scripts/run_klayout_drc.sh` conserva el `PATH` original de la imagen, le
antepone `reports/stage9/bin` y monta el PDK como solo lectura. El hecho de que el deck
esté en el PDK y pase no demuestra por sí solo que el profesor lo acepte como
runset de entrega; debe confirmarse el criterio académico. Tampoco repara las
violaciones eléctricas.

El target reproducible fue ejecutado de extremo a extremo, no solo inspeccionado
con `make -n`. Terminó con código 0 y el mismo mensaje limpio; su evidencia
independiente está en `reports/stage9/klayout_drc_repro_check/`.

## Evidencia real de antena

Se eligió la corrida reglamentaria histórica `etapa5_rom_ram_util40` porque
contiene una violación inicial y una reparación final demostrables.

Antes de reparación, `40-openroad-checkantennas/reports/antenna_summary.rpt`
contiene 18 violaciones. Un caso trazable es:

| Campo | Evidencia |
|---|---|
| Red | `u_pochoco_soc.genblk1.g_rom_ram_memory.u_ram.a_rdata_o[20]` |
| Pin afectado | `fanout575/I` |
| Capa | Metal4 |
| Relación parcial/requerida | 826,80 / 400,00 = 2,07 |
| Causa | área lateral de conductor acumulada antes de una puerta, propia de una salida de la ROM combinacional con ruta física larga |

`42-openroad-repairantennas` aplicó jumpers y diodos. Su secuencia reportada
fue 18→5→21→1→1→0; el aumento intermedio es un efecto real del reruteo, no se
oculta. En esa fase quedaron ocho celdas de antena. La red citada se conectó a
`ANTENNA_3` y `ANTENNA_8`. El DEF usa 2000 DBU/µm:

| Instancia | Coordenada DEF | Coordenada µm |
|---|---:|---:|
| `ANTENNA_3` | (721280, 878080) | (360,64; 439,04) |
| `ANTENNA_8` | (476000, 266560) | (238,00; 133,28) |

El chequeo inmediato después de insertar diodos quedó vacío y el chequeo
post-route `46-openroad-checkantennas-1` también quedó vacío. La métrica final
es `route__antenna_violation__count=0`. La corrida unificada de Etapa 4, en
cambio, conserva una violación final (`net367`, P/R 1,09) y no se presenta como
reparada.

## Corrida reglamentaria nueva

Corrida: `asic/runs/etapa9_rom_ram_util40_debounce`.

| Propiedad | Resultado real |
|---|---:|
| Arquitectura | ROM combinacional + RAM reducida |
| Período / utilización objetivo | 100 ns / 40 % |
| Área de die | 375554 µm² = 0,375554 mm² |
| Área de core | 347061 µm² = 0,347061 mm² |
| Utilización real stdcell | 52,2176 % |
| Peor slack setup (9 corners) | +37,171987 ns (`max_ss_125C_4v50`) |
| TNS setup | 0 ns en 9 corners |
| Peor slack hold (9 corners) | +0,126038 ns (`min_ff_n40C_5v50`) |
| TNS hold | 0 ns en 9 corners |
| Slew (peor corner) | 2695 |
| Capacitancia (peor corner) | 10 |
| Fanout (todos los corners) | 58 |
| Routing DRC / Magic DRC / LVS / antena / XOR | 0 / 0 / 0 / 0 / 0 |
| KLayout DRC externo | limpio con el deck instalado |
| Estado | flujo completo, **sin cierre eléctrico** |

La diferencia de área respecto de la corrida histórica se debe a una nueva
implementación física y al cambio reproducible de debounce; no se interpreta
como una optimización de área.

El diagnóstico de `max_ss_125C_4v50` está en
`reports/stage9/electrical_util40_debounce.json`: 1980 de las 2695 violaciones
de slew se clasifican directamente en instrucción/ROM/fetch; 222 en reset. Las
58 violaciones de fanout son del árbol de reloj. Las diez de capacitancia son
ocho de ROM/fetch y dos de CTS. La peor transición es `net385`, 6,292998 ns
frente a 3 ns; la peor carga es `clknet_0_clk_i`, 0,337637 frente a 0,2; los
peores fanouts de hoja CTS son 18 frente a 10.

No se realizó una reparación eléctrica adicional: las causas vuelven a ser la
ROM combinacional distribuida y CTS. Las variantes controladas de Etapas 6/6B
ya demostraron que cambiar globalmente buffering/fanout puede aumentar área o
trasladar las violaciones; no apareció una modificación acotada que garantice
equivalencia funcional y ataque solo estas redes. Hacer otro barrido masivo
habría contradicho el alcance de esta etapa.

## Matriz de cumplimiento actualizada

La matriz conserva los 25 requisitos auditados en Etapa 8. Estado global:
**17 cumplidos, 7 parciales y 1 pendiente**. Los tres cambios de estado son:
dependencias temporales FPGA/ASIC, README y evidencia de antena.

| Requisito | Estado | Evidencia | Acción restante |
|---|---|---|---|
| 3.1 conservar Proyecto 2 y juego | Cumplido | `rtl/game_top.v`, `sw/game.s`, pruebas | Ninguna |
| 3.1 top ASIC y puertos | Cumplido | `rtl/asic_top.v` | Ninguna |
| 3.1 dependencias FPGA y debounce | Cumplido | parámetros `DebounceCycles`; dos TB | Llevar explicación al informe |
| 3.2 ROM+RAM | Cumplido | memoria/ROM y pruebas | Ninguna |
| 3.2 unificada FF | Cumplido | memoria unificada y pruebas | Ninguna |
| 3.2 cantidades reales | Cumplido | 143 instrucciones y una palabra de datos | Ninguna |
| 3.2 métricas/frecuencia por memoria | Parcial | completas salvo búsqueda de Fmax unificada | Barrer período de la unificada o declarar solo 10 MHz demostrados |
| 3.3 cinco celdas más usadas | Cumplido | `reports/stage8/area_breakdown.json` | Incorporar al informe |
| 3.3 áreas jerárquicas | Cumplido | `reports/stage8/` | Incorporar método |
| 3.3 área esperada/sintetizada | Parcial | comparación cualitativa, sin predicción numérica previa | No inventar predicción retrospectiva |
| 3.3 trazabilidad RF/ALU/contador | Cumplido | CSV/SVG y análisis jerárquico | Ninguna para síntesis |
| 3.4 barrido de períodos | Cumplido | 100/70/62/60 ns | Ninguna |
| 3.4 ruta crítica | Cumplido | reporte `max_ss` de Etapa 4 | Ninguna |
| 3.4 optimización medida | Cumplido | ALU experimental empeoró y fue descartada | Mantenerla fuera |
| 3.4 temporización del juego | Cumplido | 30 M y 1 M ciclos | Ninguna |
| 3.5 floorplans/mínimo válido | Parcial | 30/40/50 completos, ninguno eléctrico | Conseguir una corrida cerrada |
| 3.5 terminales/pads | Parcial | placement automático documentado | Validar pinout exigido |
| 3.5 costo | Cumplido | cálculo y limitaciones en Etapa 5 | Ninguna |
| 3.6 DRC/LVS/antena finales | Parcial | todos limpios, incluido deck KLayout externo; electricidad falla | Repetir signoff tras cierre eléctrico y confirmar aceptación del deck |
| 3.6 violación de antena trazada | Cumplido | red, ratio, diodos, coordenadas y reportes anteriores/posteriores | Captura gráfica opcional |
| 3.6 captura RF/ALU/contador | Parcial | SVG real corresponde a `grt60`, no a diseño cerrado | Regenerar sobre eventual cierre |
| 3.7 post-síntesis | Cumplido | `mismatches=0`, logs/VCD | Ninguna para casos probados |
| Referencia 100 ns/40 % | Parcial | nueva corrida completa; eléctrico no cumple | Reparar slew/cap/fanout |
| README reproducible | Cumplido | `README.md`, targets verificados | Mantener rutas/versiones al día |
| GDSII de corrida cerrada | Pendiente | existe GDS candidato con errores eléctricos | No declarar final hasta cerrar |

## Evidencias y pendientes prioritarios

Rutas principales:

- corrida nueva: `asic/runs/etapa9_rom_ram_util40_debounce/`;
- métricas: `final/metrics.json`;
- GDS candidato: `final/gds/asic_top.gds`;
- DRC KLayout externo: `reports/stage9/klayout_drc_etapa9_util40/`;
- repetición mediante el target documentado:
  `reports/stage9/klayout_drc_repro_check/`;
- intentos fallidos preservados: `klayout_drc_util40/` y
  `klayout_drc_util40_retry2/`;
- diagnóstico eléctrico: `reports/stage9/electrical_util40_debounce.{json,csv}`;
- antena antes/después: corrida `etapa5_rom_ram_util40`, pasos 40, 42 y 46;
- regresión funcional: salida de `tests/run_tests.py` y
  `tests/periph_debounce_asic_tb.v`.

Antes de la entrega siguen siendo imprescindibles: (1) resolver o justificar
con el profesor el cierre eléctrico de slew/cap/fanout, (2) confirmar si el
deck KLayout instalado y su alcance son el criterio esperado, y (3) generar un
GDS definitivo únicamente después de repetir todas las verificaciones sobre
una corrida eléctricamente cerrada. Siguen pendientes de menor prioridad la
Fmax de memoria unificada, un pinout impuesto/validado y una captura de
trazabilidad sobre la eventual corrida final.
