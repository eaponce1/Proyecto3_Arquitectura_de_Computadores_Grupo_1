# Proyecto 3 — Etapa 6: reparación eléctrica, signoff y GDSII

Fecha de las corridas: 2026-10-23.

## Conclusión ejecutiva

No se obtuvo cierre físico completo. Las corridas completas cumplen setup y
hold en los nueve corners, routing DRC, Magic DRC, LVS, antena y XOR, pero aún
presentan violaciones eléctricas. Además, el PDK instalado no proporciona
`KLAYOUT_DRC_RUNSET`, por lo que KLayout DRC no fue ejecutado.

El mejor candidato demostrado es `etapa6_rom_ram_grt60`: reduce las
violaciones de slew del peor corner de 2400 a 542 (77.4 %) y mejora el peor
slack de setup de 40.598495 ns a 44.845306 ns. No es una corrida cerrada:
conserva 55 violaciones de fanout y tiene 3 de capacitancia. Su GDSII es un
artefacto de una corrida completa, no el GDSII final aprobado.

## Entorno y baseline

- LibreLane: 3.0.16, flujo `Classic` dockerizado.
- PDK: `gf180mcuD`, revisión Open_PDKs
  `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`.
- Biblioteca: `gf180mcu_fd_sc_mcu7t5v0`.
- Diseño: ROM combinacional + RAM reducida, ALU baseline.
- `CLOCK_PERIOD`: 100 ns.
- `FP_CORE_UTIL`: 50 %.
- Baseline: `asic/runs/etapa5_rom_ram_util50`.

No se modificó RTL, `game.s`, el número de rondas ni la ALU. Los experimentos
solo cambian opciones de implementación física aceptadas por LibreLane 3.0.16.

## Restricciones efectivas de interfaz

La corrida usa el SDC genérico de LibreLane porque no están definidos
`PNR_SDC_FILE` ni `SIGNOFF_SDC_FILE`. El archivo efectivo es
`asic/runs/etapa5_rom_ram_util50/final/sdc/asic_top.sdc`.

| Restricción | Valor efectivo |
|---|---:|
| Reloj `clk_i` | 100 ns |
| Transición del reloj | 0.15 ns |
| Incertidumbre del reloj | 0.25 ns |
| Delay de todas las entradas, incluido `rst_ni` y SPI | 20 ns |
| Delay de todas las salidas | 20 ns |
| Carga de cada salida | 0.0729 pF |
| Driver de `clk_i` | `gf180mcu_fd_sc_mcu7t5v0__inv_4/ZN` |
| Driver de las demás entradas | `gf180mcu_fd_sc_mcu7t5v0__inv_1/ZN` |
| Derate early/late | 0.95 / 1.05 |
| Máxima transición | 3 ns |
| Máxima capacitancia global | 0.2 pF |
| Máximo fanout global | 10 |

Faltan modelos de pads, paquete y placa; cargas y drivers específicos de la
interfaz; una definición explícita del dominio SPI/asíncrono; tratamiento
documentado de botones y reset como señales asíncronas; y SDC propios de PnR y
signoff. Las restricciones genéricas son reproducibles y conservadoras, pero
no representan una interfaz de chip completa.

## Diagnóstico del baseline

El reporte determinante es
`asic/runs/etapa5_rom_ram_util50/55-openroad-stapostpnr/max_ss_125C_4v50/checks.rpt`.
En `max_ss_125C_4v50` contiene 2400 violaciones de slew, 55 de fanout y una de
capacitancia.

### Diez peores violaciones de slew

| # | Pin | Slew / límite (ns) | Slack (ns) | Red | Función trazada |
|---:|---|---:|---:|---|---|
| 1 | `_7298_/ZN` | 6.120624 / 3 | -3.120624 | `_3648_` | cono combinacional fetch/decode/execute |
| 2 | `fanout36/I` | 6.120624 / 3 | -3.120624 | `_3648_` | misma red, buffer de reparación |
| 3 | `fanout37/I` | 6.120624 / 3 | -3.120624 | `_3648_` | misma red, buffer de reparación |
| 4 | `_6286_/ZN` | 5.551406 / 3 | -2.551406 | `_2730_` | decodificación de dirección ROM/RAM |
| 5 | `_6289_/A2` | 5.551406 / 3 | -2.551406 | `_2730_` | decodificación de dirección ROM/RAM |
| 6 | `_6746_/A1` | 5.551406 / 3 | -2.551406 | `_2730_` | decodificación de dirección ROM/RAM |
| 7 | `load_slew360/I` | 5.551406 / 3 | -2.551406 | `_2730_` | decodificación de dirección ROM/RAM |
| 8 | `_5476_/A2` | 5.500853 / 3 | -2.500853 | `net383` | fetch/decode desde `a_rdata_o` |
| 9 | `_5573_/B1` | 5.500855 / 3 | -2.500855 | `net383` | fetch/decode desde `a_rdata_o` |
| 10 | `_5717_/A2` | 5.500852 / 3 | -2.500852 | `net383` | fetch/decode desde `a_rdata_o` |

La copia procesable de esta evidencia está en
`docs/reports/etapa6_baseline_top10.csv`. La asociación se obtuvo cruzando
pin, red y celda del reporte con `final/nl/asic_top.nl.v`; no se dedujo solo
del nombre numérico de instancia.

Una clasificación automática del cono transitivo de las 2400 filas encontró
2225 filas alcanzables desde señales de memoria/fetch/decode, 93 desde
`rst_ni`, 7 directamente desde el register file y 75 en lógica restante. Esta
clasificación puede superponerse microarquitectónicamente porque los muxes
combinan memoria, PC y register file; se usa para localizar causas, no como
partición de área.

### Fanout y capacitancia

Las diez peores violaciones de fanout son salidas de hojas CTS
`clkbuf_leaf_{16,20,29,33,38,39,42,45,47,49}_clk_i/Z`: cada una maneja 18
cargas con límite 10. Las 55 violaciones pertenecen al árbol de reloj, no a
reset, memoria ni puertos de datos.

La única violación de capacitancia es `clkbuf_0_clk_i/Z`, red
`clknet_0_clk_i`: 0.348728 pF frente a 0.2 pF. Por tanto, el problema de
capacitancia baseline también está en CTS. En slew sí aparecen 71 pines `RN`
violados y 93 filas cuyo cono llega a `rst_ni`; reset contribuye, pero no
explica las peores diez ni la mayoría de las 2400 filas.

## Experimentos controlados

| Corrida | Cambio aislado | Estado | Slew / cap / fanout, peor corner | Stdcell (µm²) | Utilización | Setup WS peor | Hold WS peor |
|---|---|---|---:|---:|---:|---:|---:|
| `etapa5_rom_ram_util50` | baseline | completa | 2400 / 1 / 55 | 181532 | 64.4117 % | 40.598495 ns | 0.122806 ns |
| `etapa6_rom_ram_cts` | `CTS_MAX_CAP=0.2`, `CTS_MAX_SLEW=3`, clusters de 8 | completa | 2733 / 10 / 1 | 185218 | 65.7195 % | 39.646914 ns | 0.168181 ns |
| `etapa6_rom_ram_grt60` | reparación post-GRT, margen slew 60 %, cap 30 % | completa | 542 / 3 / 55 | 184302 | 65.3947 % | 44.845306 ns | 0.128327 ns |
| `etapa6_rom_ram_grt80` | margen slew 80 %, cap 60 % | falló en `RepairDesignPostGRT` | sin STA/signoff final | — | — | — | — |
| `etapa6_rom_ram_grt80_retry` | reintento idéntico | Docker no inició | sin corrida | — | — | — | — |

El experimento CTS creó 129 buffers y un árbol de cuatro niveles para 874
sinks. Redujo 55 violaciones de fanout a una, pero la raíz terminó con fanout
16 y 0.400061 pF; además aumentó slew y capacitancia. `-balance_levels` fue
reportado obsoleto por OpenROAD. Se descarta como candidato.

`grt60` detectó 1455 violaciones estimadas después de global routing e insertó
737 buffers. El post-route real quedó en 542, no en cero. Sus peores slews aún
son 5.658377 ns y 5.484709 ns. Las tres capacitancias del corner lento son:

- `clkbuf_0_clk_i/Z`: 0.353182 pF.
- `clkbuf_3_4__f_clk_i/Z`: 0.210272 pF.
- `fanout374/Z`: 0.208488 pF.

El resultado demuestra una mejora, pero no cierre. Aumentar buffers sin
control no es suficiente: CTS empeoró el conjunto y el margen post-GRT produjo
un intercambio de 2770 µm² de stdcells por menor slew.

### Fallo de infraestructura de `grt80`

La primera corrida llegó a `41-openroad-repairdesignpostgrt` y Docker terminó
con `unexpected EOF`, código 125. El reintento falló en `docker info` con HTTP
500 y `TypeError: 'NoneType' object is not iterable`. WSL2 continuó en estado
`Running`, pero el daemon no respondió. Los mensajes completos están en
`docs/reports/etapa6_docker_errors.txt`. No se reinició Docker Desktop ni WSL
porque eso podía interrumpir otros contenedores o sesiones del usuario.

## Timing post-route del mejor candidato

LibreLane reporta WNS = 0 y TNS = 0 cuando no existen slacks negativos. La
columna WS conserva el margen positivo real.

| Corner | Setup WNS / TNS | Setup WS (ns) | Hold WNS / TNS | Hold WS (ns) |
|---|---:|---:|---:|---:|
| `max_ff_n40C_5v50` | 0 / 0 | 75.819602 | 0 / 0 | 0.135468 |
| `max_ss_125C_4v50` | 0 / 0 | 44.845306 | 0 / 0 | 0.939572 |
| `max_tt_025C_5v00` | 0 / 0 | 70.217313 | 0 / 0 | 0.376683 |
| `min_ff_n40C_5v50` | 0 / 0 | 75.987411 | 0 / 0 | 0.128327 |
| `min_ss_125C_4v50` | 0 / 0 | 47.529630 | 0 / 0 | 0.922008 |
| `min_tt_025C_5v00` | 0 / 0 | 71.781488 | 0 / 0 | 0.366431 |
| `nom_ff_n40C_5v50` | 0 / 0 | 75.910175 | 0 / 0 | 0.131593 |
| `nom_ss_125C_4v50` | 0 / 0 | 46.315380 | 0 / 0 | 0.930028 |
| `nom_tt_025C_5v00` | 0 / 0 | 71.095324 | 0 / 0 | 0.371115 |

Todos los corners cumplen setup y hold; esto no compensa las violaciones
eléctricas.

## Signoff físico del mejor candidato

El área del die se conserva en 308378 µm² = 0.308378 mm²; el área del core es
281831 µm². La tabla distingue lo ejecutado de lo pendiente.

| Verificación | Resultado real | Evidencia |
|---|---|---|
| Detailed routing / routing DRC | 0 errores | `45-openroad-detailedrouting`, `48-checker-trdrc` |
| Antena post-route | 0 redes, 0 pines | `47-openroad-checkantennas-1`, métrica `route__antenna_violation__count=0` |
| STA post-route | setup/hold sin violaciones, nueve corners | `56-openroad-stapostpnr` |
| Magic DRC | 0 errores | `65-magic-drc`, `67-checker-magicdrc` |
| LVS Netgen | 0 errores/diferencias | `71-netgen-lvs`, `72-checker-lvs` |
| KLayout XOR | 0 diferencias | `63-klayout-xor`, `64-checker-xor` |
| KLayout DRC | **no ejecutado** | `66-klayout-drc`: `KLAYOUT_DRC_RUNSET is unset` |
| Power-grid connectivity | 0 violaciones | métrica `design__power_grid_violation__count=0` |
| IR drop | ejecutado con limitación | `VSRC_LOC_FILES` no definido; no es signoff de chip completo |
| Slew/cap/fanout | **no cumple** | 542 / 3 / 55 en el peor corner |

La advertencia de KLayout DRC no puede convertirse en aprobación: la revisión
instalada del PDK no suministra el runset requerido.

## GDSII

El mejor candidato genera:

- Magic: `asic/runs/etapa6_rom_ram_grt60/final/gds/asic_top.gds`,
  9441068 bytes, SHA-256
  `E26208CE0060397E26E17BCD7D5AEE6A0E8BED5C210F53E9BCA92D814487F305`.
- KLayout stream-out:
  `asic/runs/etapa6_rom_ram_grt60/final/klayout_gds/asic_top.klayout.gds`,
  6476724 bytes, SHA-256
  `32DBA5B70661C3700529554B170286278D63D31B1931EDE17C0005CD689810A5`.

Ambos corresponden a una corrida completa con violaciones eléctricas y sin
KLayout DRC. Se conservan como GDSII candidatos; ninguno se declara GDSII final
cerrado.

## Captura y trazabilidad física

La captura anotada está en
`docs/figures/etapa6_layout_trazabilidad.svg`. Embebe el PNG real generado por
KLayout para `grt60` y superpone coordenadas del DEF:

- Register file: 480 flops identificados por salidas jerárquicas
  `u_core.g_asic_regfile.u_rf.bank_a[...]`.
- Contador de ciclos: 32 flops identificados por
  `u_periph.cycle_q[...]`.
- ALU: 32 celdas driver de `u_ram.a_addr_i[...]`. Yosys eliminó el nombre
  `alu_result`, por lo que la frontera observable y reproducible es la salida
  de la ALU que alimenta la dirección de datos.

La tabla completa instancia/celda/coordenada/señal está en
`docs/figures/etapa6_trazabilidad.csv`. Como el diseño fue aplanado y no se
impusieron regiones físicas, los bloques no forman rectángulos compactos; la
captura muestra celdas trazadas, no regiones inventadas.

## Verificación funcional

`python -B tests/run_tests.py` ejecutó 16 pruebas y todas pasaron, incluidas
las diez rondas, promedio y contenido de ROM. La invocación desde Windows
informó `Icarus missing`, por lo que las pruebas Verilog/Icarus no se ejecutaron
en esta sesión. No se realizó simulación post-síntesis, conforme a la
restricción de la etapa.

## Archivos creados o modificados

- `asic/rom_ram_etapa6_cts.json`.
- `asic/rom_ram_etapa6_grt60.json`.
- `asic/rom_ram_etapa6_grt80.json`.
- `Makefile`: targets reproducibles de Etapa 6.
- `scripts/annotate_layout.py`.
- `docs/figures/etapa6_layout_trazabilidad.svg`.
- `docs/figures/etapa6_trazabilidad.csv`.
- `docs/reports/etapa6_baseline_top10.csv`.
- `docs/reports/etapa6_docker_errors.txt`.
- Este documento.

Las corridas nuevas se guardaron en directorios distintos. No se borró ni
sobrescribió ninguna corrida anterior.

## Reproducción

Desde WSL, con `/tmp/pochoco3` enlazado al proyecto:

```sh
cd /tmp/pochoco3
make etapa6-cts ETAPA6_CTS_TAG=etapa6_rom_ram_cts_repro
make etapa6-grt60 ETAPA6_GRT60_TAG=etapa6_rom_ram_grt60_repro
make etapa6-grt80 ETAPA6_GRT80_TAG=etapa6_rom_ram_grt80_repro
make etapa6-layout
```

Para reintentar `grt80`, primero Docker Desktop debe volver a responder a:

```sh
docker info
docker run --rm hello-world
```

## Pendientes para cierre

1. Recuperar Docker y completar `grt80` con STA y signoff, sin reutilizar el
   tag fallido.
2. Separar el ajuste de slew de datos de una solución CTS que mantenga cada
   rama bajo fanout 10 y la raíz bajo 0.2 pF; no reutilizar la variante CTS de
   clusters de ocho tal como está.
3. Crear SDC de interfaz justificado con datos de pad/paquete/placa y dominio
   SPI, y volver a ejecutar todos los corners.
4. Obtener o validar un runset KLayout DRC compatible con la revisión exacta
   de GF180MCU.
5. Repetir routing DRC, Magic DRC, LVS, antena, STA y verificación eléctrica
   después de cualquier reparación.
6. Solo cuando todo lo anterior esté limpio, promover un GDSII candidato a
   GDSII final.
