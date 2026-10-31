# Proyecto 3 — Etapa 8: auditoría técnica

Fecha de auditoría: 24 de octubre de 2026.

## Alcance y criterio

Se contrastó el PDF original `Proyecto_3_arquitectura.pdf` (entregado por el curso)
con el RTL, configuraciones, documentación y reportes originales. El PDF tiene
tres páginas y define las secciones 3.1 a 3.7, además de exigir en el README la
instalación, corrida final, regeneración del programa y versiones exactas.

Un archivo de documentación no se tomó por sí solo como prueba. Se revisaron
los `state_out.json`, `final/metrics.json`, logs de LibreLane, netlists, VCD y
resultados de comparación. Estado global de los 25 puntos auditados:

- **Cumplidos: 14**.
- **Parciales: 8**.
- **Pendientes: 3**.
- **Signoff completo: no demostrado**.

## Matriz de cumplimiento

| Sección y requisito | Estado | Evidencia verificable | Archivo/reporte | Acción necesaria |
|---|---|---|---|---|
| 3.1: partir del Proyecto 2 del grupo y conservar el juego | Cumplido | RTL, assembler y juego del grupo conservados; diez rondas verificadas | `rtl/`, `sw/game.s`, `docs/proyecto3_etapa1.md`, pruebas de Etapa 7 | Ninguna para este punto |
| 3.1: `asic_top.v` con reloj, reset, botones, LEDs, displays y SPI, sin pines FPGA | Cumplido | Top ASIC separado de `game_top.v`; puertos y anchos coinciden con el SoC | `rtl/asic_top.v`, `rtl/game_top.v` | Ninguna |
| 3.1: identificar y reemplazar todas las dependencias FPGA, con log/línea o explicación | Parcial | `SB_RAM40_4K`, `$readmemh`, `initial`, BRAM y power-on reset fueron identificados. No aparecen warnings en las corridas ASIC porque esos fuentes/rutas se excluyen de `VERILOG_FILES` y se reemplazan por módulos ASIC. Sin embargo, el debounce sigue fijo en 249999 ciclos, que son 10 ms a 25 MHz pero 25 ms a 10 MHz | `docs/proyecto3_etapa1.md`; `rtl/pochoco_periph.v:42-53`; configuraciones `asic/*.json`; lint de `06-yosys-synthesis` | Documentar explícitamente cada ausencia de warning en el informe y decidir/corregir de forma reproducible el debounce ASIC sin alterar la variante FPGA |
| 3.2: ROM combinacional generada por assembler y RAM reducida | Cumplido | ROM `case` sin `$readmemh/initial`; una palabra de datos en `0x7FC`; latencia registrada | `sw/assembler.py`, `rtl/pochoco_memory_rom_ram.v`, `asic/generated/game_rom.v` | Ninguna |
| 3.2: memoria unificada con flip-flops dimensionada al juego | Cumplido | 143 palabras de programa y una de datos; inicialización hardware y reset retenido hasta completar carga | `rtl/pochoco_memory_unified_ff.v`, `docs/proyecto3_etapa2.md` | Ninguna |
| 3.2: cantidades reales de programa y datos | Cumplido | 143 instrucciones/572 bytes; una palabra de datos no MMIO; MMIO identificado aparte | `sw/game.hex`, `tests/test_asic_memory.py`, `docs/proyecto3_etapa2.md` | Ninguna |
| 3.2: área, FF, utilización y frecuencia máxima para cada memoria | Parcial | Hay área, FF y utilización de ambas. ROM+RAM demostró 62 ns/16,129 MHz; la unificada solo fue probada a 100 ns/10 MHz, por lo que su frecuencia máxima no fue buscada | Corridas `etapa4_rom_ram_100ns_*`, `etapa4_unified_ff_100ns_100` | Barrer al menos un período menor para la unificada o declarar explícitamente que solo existe una frecuencia demostrada de 10 MHz, no una máxima |
| 3.3: cinco celdas estándar más usadas y función | Cumplido | Conteos extraídos del JSON aplanado de la corrida reglamentaria de 40 % | `reports/stage8/area_breakdown.json`; `etapa5_rom_ram_util40/06-yosys-synthesis/asic_top.nl.v.json` | Incorporar la tabla al informe final |
| 3.3: módulo de mayor área, register file, ALU y contador con fracción | Cumplido | Nueva síntesis diagnóstica preservando jerarquía con Yosys 0.62 y la misma Liberty; contador trazado como cono hacia los 32 FF `cycle_q` | `scripts/stage8_hier_area.ys`, `scripts/analyze_stage8_area.py`, `reports/stage8/hier_stat.json`, `area_breakdown.json`, `hier_synthesis.log` | Incorporar método y limitación de flattening al informe |
| 3.3: comparar área esperada frente a sintetizada | Parcial | Se documentó la expectativa cualitativa de que ROM+RAM sería menor que FF unificada y se confirma 3,99× en síntesis. No existe una estimación numérica previa, fechada antes de sintetizar | `docs/proyecto3_etapa2.md`, reportes de Etapas 3/4 | No inventar una predicción retrospectiva; comparar cualitativamente y explicar el predominio inesperado del register file |
| 3.3: conservar o reconstruir trazabilidad de RF, ALU y contador | Cumplido | RF y contador conservan nets jerárquicas; ALU se rastrea por la frontera de dirección de datos después del flattening | `docs/figures/etapa6_trazabilidad.csv`, `scripts/annotate_layout.py`, netlist final | Ninguna para síntesis; ver limitación de layout en 3.6 |
| 3.4: barrer al menos tres períodos incluyendo 100 ns y reportar corners | Cumplido | 100, 70, 62 y 60 ns; 62 ns cumple nueve corners y 60 ns falla setup SS | `etapa4_rom_ram_100ns_{100,70,62,60}/55-openroad-stapostpnr` | Ninguna |
| 3.4: identificar ruta crítica de inicio a fin y función | Cumplido | Inicio `_8522_`, fin `_8510_`; fetch→decode/salto→PC; reporte celda por celda | `etapa4_rom_ram_100ns_100/55-openroad-stapostpnr/max_ss_125C_4v50/max.rpt` | Ninguna |
| 3.4: proponer, implementar y medir una optimización RTL | Cumplido | ALU experimental empeoró WNS/TNS y área; se conservó pero no se seleccionó | `asic/optimized/espino_alu.v`, corrida `etapa4_rom_ram_opt_60` | Mantenerla fuera de la candidata principal |
| 3.4: recalcular tres segundos y décimas a 100 ns y regenerar | Cumplido | 30 000 000 y 1 000 000 ciclos; programa ASIC de 143 palabras reproducible | `sw/game_asic_100ns.s`, `make asic-rom-100ns`, `asic/generated/` | Ninguna |
| 3.5: tres floorplans y área mínima que completa según criterios | Parcial | 30/40/50 % completan el flujo, pero ninguno cumple eléctricamente y falta KLayout DRC. Existe mínimo probado, no mínimo válido | Corridas `etapa5_rom_ram_util{30,40,50}`, `docs/proyecto3_etapa5.md` | Conseguir una corrida cerrada; no presentar 0,308378 mm² como mínimo de signoff |
| 3.5: justificar terminales y distinguir macro de pads | Parcial | Posiciones reales y distinción macro/pads están documentadas. El placement fue automático, sin `FP_PIN_ORDER_CFG`; por ello no existe un pinout funcionalmente impuesto | `docs/proyecto3_etapa5.md`, `docs/figures/etapa5_pinout_util50.svg` | Definir/validar un orden de terminales o presentar honestamente el automático como observación, no como decisión optimizada |
| 3.5: costo equivalente y limitaciones | Cumplido | Cálculo por área de die y US$23000/mm², con limitaciones de NRE, yield, pads y encapsulado | `docs/proyecto3_etapa5.md` | Ninguna |
| 3.6: DRC, LVS y antena finales limpios | Parcial | Routing DRC, Magic DRC, LVS, antena y XOR dan cero en corridas candidatas. KLayout DRC fue omitido por falta de runset y persisten errores eléctricos | `etapa6b_rom_ram_grt70_cts10`, `flow.log`, checkers 48/65/67/72; `66-klayout-drc` | Obtener runset KLayout si es exigido y repetir signoff después de reparar electricidad |
| 3.6: describir, ubicar y resolver una violación de antena aparecida durante desarrollo | Pendiente | La unificada de Etapa 4 reportó una violación de antena, pero no hay una descripción con ubicación, captura y reparación documentada | `docs/proyecto3_etapa4.md`; corrida `etapa4_unified_ff_100ns_100` | Elegir esa violación u otra evidencia real, localizarla y explicar su resolución sin inventar |
| 3.6: captura anotada de register file, ALU y contador | Parcial | Existe SVG basado en PNG real y CSV de celdas/coordenadas. RF y contador son directos; la ALU usa una frontera observable porque su nombre fue eliminado. La captura corresponde a `grt60`, no a un layout eléctricamente cerrado | `docs/figures/etapa6_layout_trazabilidad.svg`, `etapa6_trazabilidad.csv` | Regenerar la captura para la eventual corrida final cerrada y reforzar la trazabilidad de ALU con el método jerárquico de Etapa 8 |
| 3.7: simulación post-síntesis sin retardos; ronda correcta e incorrecta | Cumplido | Cosimulación ciclo a ciclo RTL/netlist, modelos GF180 reales, `mismatches=0`; además diez rondas y promedio | `tests/stage7/`, `docs/proyecto3_etapa7.md`, VCD y logs | Ninguna para los casos exigidos |
| Parámetros finales: 100 ns y `FP_CORE_UTIL=40` | Parcial | La corrida exacta existe y completó el flujo; timing cumple nueve corners y DRC/LVS/antena son cero. Conserva 3008 slew, 31 cap y 56 fanout; KLayout DRC no corrió | `etapa5_rom_ram_util40`, `asic/rom_ram_util40.json` | Reparar la configuración reglamentaria de 40 % y repetir todas las verificaciones |
| README reproducible con instalación, corrida final, regeneración y versiones | Pendiente | El README actual solo documenta FPGA. Los comandos ASIC existen en Makefile/docs, pero no en el lugar exigido | `README.md`, `Makefile`, documentación de Etapas 3–7 | Añadir una sección ASIC al README antes de entregar |
| GDSII de una corrida cerrada | Pendiente | Hay GDS de corridas completas, pero con violaciones eléctricas y sin KLayout DRC | `etapa6b_rom_ram_grt70_cts10/final/gds/asic_top.gds` | Solo declarar final un GDS obtenido después de cierre reglamentario |

## Síntesis de la corrida reglamentaria

La fuente de los conteos es la síntesis de `etapa5_rom_ram_util40`, que usa
ROM+RAM, 100 ns, 40 % y la ALU baseline. Su área Yosys aplanada es
**142038,2208 µm²**, con 5140 celdas y 874 FF.

### Cinco celdas más utilizadas

| Celda GF180 | Cantidad | Función física/lógica | Explicación respaldada |
|---|---:|---|---|
| `dffrnq_1` | 871 | FF D de flanco positivo con reset activo-bajo | Estado secuencial. La estadística jerárquica muestra 544 FF solo en el register file, 142 en periféricos y 96 en memoria ROM+RAM |
| `nand2_1` | 841 | NAND de dos entradas | Forma parte de la red booleana aplanada: decodificación de ROM, muxes y control. ABC perdió la atribución exacta por módulo |
| `oai21_1` | 588 | OR-AND-Invert de tres entradas | Implementa selectores y condiciones compuestas después del flattening |
| `nor2_1` | 452 | NOR de dos entradas | Decodificación/comparación y red combinacional de ROM/control |
| `aoi21_1` | 409 | AND-OR-Invert de tres entradas | Selectores, comparaciones y reducción lógica |

No se asigna una cantidad inventada de NAND/OAI/NOR/AOI a un único módulo:
ABC optimizó entre fronteras después de `flatten`. Los conteos y tipos sí son
exactos; su atribución detallada no se preservó.

### Áreas jerárquicas

Se ejecutó una síntesis diagnóstica separada con la misma imagen Docker,
Yosys 0.62 y Liberty TT, pero sin `flatten`. El área jerárquica total fue
**141924,0704 µm²**, una diferencia de 114,1504 µm² o 0,0804 % respecto del
resultado aplanado. La diferencia proviene de optimizaciones que atraviesan
fronteras y del mapeo independiente por módulo.

| Elemento | Área (µm²) | Fracción del total jerárquico | Método |
|---|---:|---:|---|
| Register file `espino_register_file_ff` | 69071,9680 | 48,668 % | Área del módulo hoja preservado |
| ALU `espino_alu` | 7448,3136 | 5,248 % | Área del módulo hoja preservado |
| Contador libre `cycle_q` | 3714,2784 | 2,617 % | Cono inverso de 97 celdas desde los 32 FF mapeados de `cycle_q` |
| ROM `game_rom` | 9568,8768 | 6,742 % | Área del módulo hoja preservado |
| Periférico completo | 17436,4736 | 12,286 % | Incluye contador, captura, debounce, LEDs y displays |
| SoC total jerárquico | 141924,0704 | 100 % | `stat -top asic_top -liberty ... -json` |

El **register file es el mayor módulo hoja**. Antes de sintetizar solo se había
registrado una expectativa cualitativa: la memoria unificada con FF debía ser
mucho mayor que ROM+RAM. Eso se confirmó, pero no existía una predicción
numérica por módulo. También resulta relevante que Yosys puede combinar
almacenamiento lógicamente idéntico de los dos bancos del register file; por
eso no es correcto estimar su área multiplicando registros RTL sin observar
la síntesis.

## Comparaciones consolidadas

### Arquitecturas de memoria

Comparación a 100 ns y 40 %, usando la misma imagen ASIC de 143 instrucciones:

| Métrica | ROM + RAM | Unificada FF |
|---|---:|---:|
| Palabras de programa / datos | 143 / 1 | 143 / 1; 144 físicas |
| Área Yosys (µm²) | 142038,2208 | 566548,1920 |
| FF mapeados | 874 | 5317 |
| Celdas sintetizadas | 5140 | 17660 |
| Stdcell post-route (µm²) | 184179 | 730205 |
| Die (mm²) | 0,382215 | 1,470110 |
| Utilización stdcell post-route | 51,8778 % | 51,6617 % |
| Menor período demostrado | 62 ns | 100 ns |
| Frecuencia demostrada | 16,129 MHz | 10 MHz; no es máximo probado |
| Antena en esa corrida | 0 | 1 |

La unificada usa 3,989× el área de síntesis, 6,084× los FF, 3,965× el área
stdcell post-route y 3,846× el die. Esto respalda ROM+RAM como candidata.

### Barrido de período y corners representativos

Todos los hold WNS/TNS de esta tabla son 0/0. El corner lento es
`max_ss_125C_4v50`; el típico es `nom_tt_025C_5v00`.

| Período | Typical setup WS / WNS / TNS (ns) | Slow setup WS / WNS / TNS (ns) | Hold WS typical / slow (ns) | Resultado nueve corners |
|---:|---|---|---|---|
| 100 ns | 67,579 / 0 / 0 | 38,023 / 0 / 0 | 0,385 / 0,965 | Cumple timing |
| 70 ns | 37,579 / 0 / 0 | 8,023 / 0 / 0 | 0,385 / 0,965 | Cumple timing |
| 62 ns | 29,579 / 0 / 0 | 0,023 / 0 / 0 | 0,385 / 0,965 | Cumple timing; mínimo demostrado |
| 60 ns | 27,579 / 0 / 0 | -1,977 / -1,977 / -26,791 | 0,385 / 0,965 | Falla setup |

Cada período puede provocar una nueva optimización; en estas cuatro corridas
baseline las áreas resultaron iguales, pero no debe asumirse como regla.

### Optimización de ALU a 60 ns

| Variante | Setup WNS/TNS slow (ns) | Placement (µm²) | Stdcell post-route (µm²) | Resultado |
|---|---:|---:|---:|---|
| Baseline | -1,977 / -26,791 | 153524 | 184179 | Falla setup |
| ALU experimental | -7,069 / -264,994 | 155010 | 186348 | Empeora 5,092 ns; descartada |

### Utilización objetivo

| Objetivo | Stdcell post-route (µm²) | Core / die (mm²) | Util. real | Uso GRT / overflow | Slew/cap/fanout | Setup/hold | DRC/Magic/LVS/antena | Cierre |
|---:|---:|---|---:|---|---:|---|---|---|
| 30 % | 187986 | 0,471748 / 0,504709 | 39,8488 % | 20,49 % / 0 | 3364/26/58 | 9 corners cumplen | 0/0/0/0 | No |
| 40 % | 184179 | 0,355025 / 0,382215 | 51,8778 % | 24,78 % / 0 | 3008/31/56 | 9 corners cumplen | 0/0/0/0 | No |
| 50 % | 181532 | 0,281831 / 0,308378 | 64,4117 % | 28,64 % / 0 | 2400/1/55 | 9 corners cumplen | 0/0/0/0 | No |

### Reparación eléctrica

| Corrida | Slew/cap/fanout | Peor slack S/C/F | Stdcell (µm²) | Util. | Resultado |
|---|---:|---|---:|---:|---|
| `etapa6_rom_ram_grt60` | 542/3/55 | -2,658/-0,153/-8 | 184302 | 65,3947 % | Baseline completa, no cierra |
| `etapa6b_rom_ram_grt70` | 125/27/55 | -2,528/-0,152/-8 | 210430 | 74,6653 % | Menos slew, más cap |
| `etapa6b_rom_ram_grt70_cts10` | 143/27/1 | -1,943/-0,195/-6 | 216293 | 76,7457 % | Mejor balance; no cierra |
| `...cts10_dist100` | 188/30/0 | -2,681/-0,084/0 | 216853 | 76,9443 % | Fanout limpio, peor slew |
| `...cts10_dist200` | 180/29/0 | -3,207/-0,087/0 | 216155 | 76,6967 % | Fanout limpio, peor slew |
| `...cap40_cts10` | 161/21/1 | -1,685/-0,196/-6 | 216614 | 76,8594 % | Menos cap, más violaciones totales |
| `etapa6b_rom_ram_grt80_v2` | N/D | N/D | N/D | N/D | Falló detailed placement |

El mejor compromiso eliminó 399 de 542 slews y 54 de 55 fanouts, pero añadió
24 violaciones de capacitancia. No existe candidato con cierre eléctrico.

### Simulación RTL frente a post-síntesis

| Caso | RTL | Netlist | Ciclos | Coincidencia |
|---|---|---|---:|---|
| A correcta | objetivo 8, score 1 | objetivo 8, score 1 | 47/47 | Exacta |
| B incorrecta | `EE`, score 0, reinicio | `EE`, score 0, reinicio | 37/37 | Exacta |
| C diez rondas | score 10, promedio `01` | score 10, promedio `01` | 47…110 | Exacta; `mismatches=0` |

## Auditoría especial de la corrida obligatoria

`etapa5_rom_ram_util40` usa exactamente `CLOCK_PERIOD=100 ns`,
`FP_CORE_UTIL=40`, `gf180mcuD` y `gf180mcu_fd_sc_mcu7t5v0`.

- El flujo terminó (`flow.log:304`).
- Setup y hold tienen WNS=0/TNS=0 en los nueve corners.
- Routing DRC, Magic DRC, LVS y antena son cero.
- KLayout DRC fue omitido: `flow.log:261`, `KLAYOUT_DRC_RUNSET is unset`.
- Quedan **3008 slew, 31 capacitancia y 56 fanout** en el peor corner.

Por tanto, es la corrida de comparación obligatoria, pero **no es una corrida
final cerrada**. El mejor candidato eléctrico de 6B usa 50 %, de modo que
tampoco reemplaza el requisito reglamentario de 40 %.

## Reproducibilidad comprobada

1. La regeneración de `game.s` produce las mismas 143 palabras y el mismo
   Verilog. En Windows los archivos conservados usan CRLF y WSL genera LF; al
   normalizar fin de línea, el contenido coincide exactamente.
2. `game_asic_100ns.s` regenera `game_100ns.hex` y `game_rom.v` byte por byte.
3. `MemoryArchitecture=1/2`, `asic/rom_ram*.json` y `unified_ff*.json`
   permiten seleccionar ambas memorias.
4. Los targets de síntesis se resuelven con `make -n`; las corridas reales y
   sus logs están bajo `asic/runs/<tag>`.
5. `make stage7-run ETAPA7_TAG=etapa7_rom_ram_post_synth` reproduce la
   cosimulación y la comparación automática.
6. La ALU baseline está en `asic/baseline`; la experimental descartada está
   aislada en `asic/optimized`.

La reproducibilidad práctica existe en Makefile y documentos, pero el README
no la expone todavía como exige el PDF.

## Versiones consolidadas

- LibreLane: **3.0.16**.
- Yosys de LibreLane: **0.62**, commit
  `7326bb7d6641500ecb285c291a54a662cb1e76cf`.
- PDK: **gf180mcuD**, revisión Open_PDKs
  `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`.
- Biblioteca: **gf180mcu_fd_sc_mcu7t5v0**.
- Docker Engine registrado: **29.7.2**.
- Python WSL: **3.12.3**.
- Icarus: **12.0 stable**.
- GTKWave: **3.3.116**.

## Pendientes priorizados antes de entregar

### Imprescindibles

1. Obtener cierre eléctrico en una corrida de **100 ns y 40 %**, repetir los
   nueve corners y todos los checkers, y conservar un nuevo tag.
2. Añadir al `README.md` instalación de LibreLane, montaje/ruta WSL, revisión
   PDK/SCL, regeneración de programa, corrida final y pruebas post-síntesis.
3. Obtener/validar el runset KLayout DRC o acordar explícitamente con el curso
   si Magic DRC es la verificación aceptada; no marcar KLayout como aprobado.
4. Generar y señalar como final únicamente el GDS de la corrida cerrada.
5. Resolver/documentar el debounce a 10 MHz; la prueba de Etapa 7 lo bypassa y
   no demuestra su duración física.

### Necesarios para satisfacer literalmente el informe

6. Documentar una violación de antena real aparecida durante desarrollo, su
   ubicación y resolución.
7. Actualizar la captura/trazabilidad para la futura corrida final y reforzar
   la identificación de ALU con la estadística jerárquica.
8. Explicar que no existió una estimación numérica previa de área, en vez de
   inventarla, y comparar la expectativa cualitativa con los datos.
9. Si se pretende afirmar frecuencia máxima para la memoria unificada, hacer
   su barrido; hoy solo se demostraron 10 MHz.
10. Decidir si el placement automático de terminales es suficiente para la
    defensa o definir un orden reproducible y funcionalmente justificado.

No se creó el PDF final y no se declara signoff completo.

