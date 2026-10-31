# Proyecto 3 — Etapa 6B: diagnóstico y reparación eléctrica

Fecha de ejecución: 23–24 de octubre de 2026. Todas las corridas usan LibreLane 3.0.16, OpenROAD incluido en su imagen Docker, `gf180mcuD` revisión `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`, biblioteca `gf180mcu_fd_sc_mcu7t5v0`, ROM + RAM, `CLOCK_PERIOD=100 ns` y `FP_CORE_UTIL=50`. No se modificó RTL ni `game.s`.

## Entorno recuperado

- Docker Desktop no estaba ejecutándose. Se inició de forma normal mediante su acceso directo; no se borraron imágenes, volúmenes ni corridas.
- Docker Engine: 29.7.2. `docker info` respondió y `docker run --rm hello-world` terminó correctamente.
- LibreLane: 3.0.16 desde `.venv-librelane-stage3`.
- PDK: `~/.ciel/ciel/gf180mcu/versions/8afc8346a57fe1ab7934ba5a6056ea8b43078e71/gf180mcuD`.
- La ruta Windows contiene un espacio (`Edu Ponce`). Yosys/ABC separó esa ruta y abortó la primera tentativa `etapa6b_rom_ram_grt80`. Para no mover el repositorio se creó un bind mount temporal y reversible en `/tmp/pochoco3`. Las corridas posteriores se hicieron desde ese alias.

## Restricciones efectivas

La configuración no define `PNR_SDC_FILE` ni `SIGNOFF_SDC_FILE`; LibreLane usa su SDC genérico. Los valores resueltos son:

| Restricción | Valor |
|---|---:|
| Reloj | `clk_i`, 100 ns |
| Incertidumbre / transición de reloj | 0,25 ns / 0,15 ns |
| Delay de entradas y salidas | 20 ns para todos los puertos |
| Driver de entradas / reloj | `inv_1/ZN` / `inv_4/ZN` |
| Carga de cada salida | 72,91 fF = 0,07291 pF |
| Máxima transición | 3 ns |
| Máxima capacitancia | 0,2 pF |
| Máximo fanout | 10 |

No existe información del encapsulado, pads, placa ni cargas externas reales. Por tanto, los 20 ns, 72,91 fF y drivers anteriores son hipótesis genéricas del flujo, no requisitos demostrados de la interfaz. No se relajó ninguno de estos límites durante 6B.

## Diagnóstico de la baseline GRT60

El reporte analizado es `asic/runs/etapa6_rom_ram_grt60/56-openroad-stapostpnr/max_ss_125C_4v50/checks.rpt`. El script `scripts/analyze_electrical.py` cruza ese reporte con el netlist físico y deja evidencia en `docs/reports/etapa6b_grt60_networks.csv` y `docs/reports/etapa6b_grt60_summary.json`.

Clasificación de las 542 violaciones de slew:

| Origen trazado | Pines violados |
|---|---:|
| Instrucción / ROM / fetch | 362 |
| Cono mixto ROM, memoria, register file y periféricos | 99 |
| Memoria de datos | 42 |
| Otra lógica combinacional | 14 |
| Cono ROM, memoria y register file | 9 |
| Register file | 8 |
| Reset | 6 |
| ROM y register file | 2 |

Las 55 violaciones de fanout pertenecen al árbol de reloj: los buffers hoja `clkbuf_8` manejan hasta 18 cargas con límite 10. Las tres violaciones de capacitancia son `clknet_0_clk_i` (0,353182 pF), `clknet_3_4__leaf_clk_i` (0,210272 pF) y `net374` de ROM/fetch (0,208488 pF), todas contra 0,2 pF. No se encontraron violaciones eléctricas dominantes en puertos externos. Reset aporta solo 6 de 542 slews; no es la causa principal.

Diez redes con más pines de slew violados (el orden es por cantidad, no por severidad):

| # | Red | Pines | Peor transición / slack (ns) | Driver | Clase |
|---:|---|---:|---:|---|---|
| 1 | `net477` | 9 | 3,229937 / -0,229937 | `fanout477/Z`, `buf_1` | ROM/fetch |
| 2 | `net270` | 9 | 3,135664 / -0,135664 | `fanout270/Z`, `buf_1` | control (`stall`) |
| 3 | `data_wdata[5]` | 8 | 4,757535 / -1,757535 | `_9302_/Q`, `dffrnq_1` | memoria de datos |
| 4 | `net369` | 8 | 4,228909 / -1,228909 | `fanout369/Z`, `buf_1` | ROM/fetch |
| 5 | `net170` | 8 | 4,163241 / -1,163242 | muxes y `fanout170` | cono mixto |
| 6 | `net427` | 8 | 4,157962 / -1,157963 | `fanout427/Z`, `buf_1` | ROM/fetch |
| 7 | `net572` | 8 | 4,115482 / -1,115482 | `fanout572/Z`, `buf_1` | ROM/fetch |
| 8 | `net391` | 8 | 4,025705 / -1,025705 | `fanout391/Z`, `buf_1` | ROM/fetch |
| 9 | `net543` | 8 | 3,975360 / -0,975360 | `fanout543/Z`, `buf_1` | ROM/fetch |
| 10 | `data_wdata[0]` | 8 | 3,932754 / -0,932754 | `_9297_/Q`, `dffrnq_1` | memoria de datos |

La peor severidad absoluta de la baseline está en `_3828_`, driver `_7671_/ZN` (`nor2_1`): 5,658377 ns y slack -2,658377 ns. Esto confirma dos causas independientes: una red combinacional grande producida principalmente por ROM/fetch y un CTS que no respeta el fanout global 10.

## Experimentos controlados

| Corrida | Cambio respecto del candidato anterior | Slew | Cap | Fanout | Peor slack S/C/F | Área stdcell (µm²) | Util. | Congestión GRT / overflow | Estado |
|---|---|---:|---:|---:|---|---:|---:|---|---|
| `etapa6_rom_ram_grt60` | Baseline | 542 | 3 | 55 | -2,658 / -0,153 / -8 | 184302 | 65,3947 % | 29,27 % / 0 | Completa |
| `etapa6b_rom_ram_grt70` | slew margin 60→70 % | 125 | 27 | 55 | -2,528 / -0,152 / -8 | 210430 | 74,6653 % | 31,41 % / 0 | Completa |
| `etapa6b_rom_ram_grt70_cts10` | cluster CTS máximo 10 | 143 | 27 | 1 | -1,943 / -0,195 / -6 | 216293 | 76,7457 % | 32,34 % / 0 | Completa; mejor balance |
| `...cts10_dist100` | distancia CTS 100 µm | 188 | 30 | 0 | -2,681 / -0,084 / 0 | 216853 | 76,9443 % | 32,33 % / 0 | Completa; descartada |
| `...cts10_dist200` | distancia CTS 200 µm | 180 | 29 | 0 | -3,207 / -0,087 / 0 | 216155 | 76,6967 % | 32,29 % / 0 | Completa; descartada |
| `...grt70_cap40_cts10` | cap margin 30→40 % | 161 | 21 | 1 | -1,685 / -0,196 / -6 | 216614 | 76,8594 % | 32,52 % / 0 | Completa; descartada por total |
| `etapa6b_rom_ram_grt80_v2` | slew/cap margin 80/60 % | — | — | — | — | — | — | — | Falló en reparación post-GRT |

GRT80 encontró 4626 slews y 510 caps bajo su margen interno, redimensionó 2730 instancias e intentó insertar 2907 buffers en 4551 redes. Detailed placement abortó con `[DPL-0036] Detailed placement failed`; esto demuestra el límite práctico de aumentar márgenes sin controlar densidad. La tentativa previa `etapa6b_rom_ram_grt80` falló antes en ABC por la ruta con espacio y también se conservó.

GRT70 redujo 417 de las 542 violaciones de slew (76,9 %), pero convirtió parte del problema en carga: cap subió de 3 a 27. CTS10 redujo fanout de 55 a 1; la única restante es `clknet_0_clk_i`, conducida por `clkbuf_16`, con 16 cargas y slack -6. Esa misma raíz tiene 0,395318 pF y explica la peor capacitancia del candidato. Las distancias CTS de 100 y 200 µm eliminaron fanout, pero empeoraron el slew de datos por el cambio de placement; no constituyen cierre.

## Timing del mejor candidato

Mejor compromiso demostrado: `etapa6b_rom_ram_grt70_cts10`. LibreLane reporta WNS=0 y TNS=0 cuando no hay violaciones; se incluye además el peor slack positivo (`WS`) para no perder margen real.

| Corner | Setup WS / WNS / TNS (ns) | Hold WS / WNS / TNS (ns) | Slew / Cap / Fanout |
|---|---|---|---:|
| min_ff_n40C_5v50 | 75,137 / 0 / 0 | 0,129 / 0 / 0 | 0 / 14 / 1 |
| min_tt_025C_5v00 | 65,351 / 0 / 0 | 0,369 / 0 / 0 | 0 / 16 / 1 |
| min_ss_125C_4v50 | 35,489 / 0 / 0 | 0,929 / 0 / 0 | 36 / 16 / 1 |
| nom_ff_n40C_5v50 | 75,062 / 0 / 0 | 0,133 / 0 / 0 | 0 / 24 / 1 |
| nom_tt_025C_5v00 | 64,486 / 0 / 0 | 0,374 / 0 / 0 | 0 / 24 / 1 |
| nom_ss_125C_4v50 | 33,930 / 0 / 0 | 0,938 / 0 / 0 | 73 / 25 / 1 |
| max_ff_n40C_5v50 | 74,971 / 0 / 0 | 0,137 / 0 / 0 | 0 / 27 / 1 |
| max_tt_025C_5v00 | 63,424 / 0 / 0 | 0,380 / 0 / 0 | 0 / 27 / 1 |
| max_ss_125C_4v50 | 32,039 / 0 / 0 | 0,948 / 0 / 0 | 143 / 27 / 1 |

Setup y hold cumplen en los nueve corners, pero eso no equivale a cierre eléctrico.

## Signoff físico y GDSII

En las cinco corridas completas nuevas:

- Routing DRC: 0; en CTS10 las iteraciones bajaron 2774 → 1130 → 960 → 7 → 0.
- Magic DRC: 0.
- LVS: 0 diferencias/errores.
- Antena post-route: 0 redes y 0 pines.
- XOR KLayout/Magic: 0 diferencias.
- Setup y hold post-route: 0 violaciones en nueve corners.
- KLayout DRC: **no ejecutado**; `KLAYOUT_DRC_RUNSET` permanece sin definir para este PDK.
- IR drop se ejecutó, pero `VSRC_LOC_FILES` no está definido; el resultado no representa un chip con fuentes físicas caracterizadas.

El die se mantuvo en 308378 µm² = 0,308378 mm² y el core en 281831 µm². El GDS de CTS10 está en `asic/runs/etapa6b_rom_ram_grt70_cts10/final/gds/asic_top.gds`; también existe `final/klayout_gds/asic_top.klayout.gds`. **No son GDS finales de cierre**, porque quedan 143 slew, 27 cap, 1 fanout y KLayout DRC pendiente.

## Comandos reproducibles

Preparación del alias sin espacios (requiere root dentro de WSL y solo si `/tmp/pochoco3` no está montado):

```sh
sudo mkdir -p /tmp/pochoco3
sudo mount --bind '/mnt/c/Users/Edu Ponce/Downloads/Proyecto-2_Juego-en-Assembly-main/Proyecto-2_Juego-en-Assembly-main/Proyecto-2_Juego-en-Assembly/Proyecto-2_Juego-en-Assembly/pochoco_soc-main' /tmp/pochoco3
cd /tmp/pochoco3
```

Ejemplo de corrida y análisis:

```sh
.venv-librelane-stage3/bin/python -m librelane --docker-no-tty --dockerized \
  --manual-pdk --condensed --hide-progress-bar -j 4 \
  --run-tag etapa6b_rom_ram_grt70_cts10 \
  asic/rom_ram_etapa6b_grt70_cts10.json

python scripts/analyze_electrical.py \
  asic/runs/etapa6b_rom_ram_grt70_cts10 \
  --csv docs/reports/etapa6b_grt70_cts10_networks.csv \
  --json docs/reports/etapa6b_grt70_cts10_summary.json
```

Las demás configuraciones están en `asic/rom_ram_etapa6b_*.json`. Cada corrida conserva `flow.log`, `warning.log`, `resolved.json`, logs por etapa y `final/metrics.json` dentro de su directorio independiente.

## Conclusión y trabajo pendiente

No se consiguió cierre eléctrico completo. El mejor balance probado es GRT70+CTS10: elimina 399 de 542 slews, 54 de 55 fanouts y mejora la peor transición de 5,658 a 4,943 ns, a costa de 24 capacitancias adicionales y 11,35 puntos de utilización. Las variantes con distancia CTS eliminan fanout por completo, pero empeoran slew; Cap40 reduce caps a 21 y mejora severidad de slew, pero deja más violaciones totales.

Para continuar sin ocultar errores se necesita: (1) acordar un SDC de interfaz real con pads/cargas/transiciones, (2) estudiar una jerarquía CTS o reparación selectiva de la raíz que mantenga fanout ≤10, (3) reducir la profundidad/carga de la ROM combinacional mediante una modificación microarquitectónica funcionalmente verificada o una macro de memoria, y (4) obtener un runset KLayout DRC válido para GF180MCU. Hasta entonces el GDSII debe tratarse como artefacto de una corrida completa con violaciones, no como entrega final cerrada.
