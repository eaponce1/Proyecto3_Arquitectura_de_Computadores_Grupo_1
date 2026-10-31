# Proyecto 3 — Etapa 7: simulación funcional post-síntesis

Fecha de ejecución: 24 de octubre de 2026.

## Resultado

La simulación funcional sin retardos del netlist sintetizado reproduce ciclo a
ciclo el RTL en las tres pruebas solicitadas. Se compararon en cada flanco los
LEDs, ambos displays, el registro crudo del display, el número de rondas
correctas y SPI MISO. La corrida terminó después de 10 551 ciclos con cero
divergencias. Esto demuestra equivalencia para los estímulos ejercitados; no es
una prueba formal exhaustiva ni reemplaza el cierre eléctrico pendiente.

| Prueba | RTL | Post-síntesis | Ciclos de respuesta | Coincidencia | Estado final |
|---|---|---|---:|---|---|
| A — ronda correcta | objetivo `8`, puntaje `1`, display `00` | objetivo `8`, puntaje `1`, display `00` | 47 / 47 | exacta | ronda completada |
| B — botón incorrecto | objetivo `4`, botón `1`, `EE`, puntaje `0` | objetivo `4`, botón `1`, `EE`, puntaje `0` | 37 / 37 | exacta | la misma ronda reiniciada, sin incrementar puntaje |
| C — diez rondas | puntaje `10`, promedio `01` | puntaje `10`, promedio `01` | 47, 54, 61, 68, 75, 82, 89, 96, 103 y 110 en ambos | exacta | estado final de espera permanente |

La comparación secundaria de los logs encontró 13 registros `RESULT` en cada
ejecución y reportó `exact_match=true`. No se aceptó solo la igualdad visual:
los ciclos aplicados, puntaje interno, dato crudo del display y salidas externas
también fueron iguales.

## Netlist y biblioteca

- Configuración: `asic/rom_ram_stage7_sim.json`, arquitectura ROM + RAM
  (`MemoryArchitecture=1`), ALU baseline y reloj declarado de 100 ns.
- Corrida: `asic/runs/etapa7_rom_ram_post_synth`.
- Netlist de Yosys: `06-yosys-synthesis/asic_top.nl.v`.
- SHA-256 del netlist:
  `3f7dc4b34f73ffc159fc5952586d9a1ecdcd589202dfb1fedc47e56fd465107a`.
- LibreLane: 3.0.16. La síntesis reportó 4 777 instancias, cero instancias no
  mapeadas, cero errores de `check`, cero latches inferidos y 16 advertencias de
  lint.
- PDK: `gf180mcuD`, revisión
  `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`.
- Biblioteca: `gf180mcu_fd_sc_mcu7t5v0`.
- Modelos Verilog usados:
  `~/.ciel/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/primitives.v`
  y `gf180mcu_fd_sc_mcu7t5v0.v` del mismo directorio.
- Se definió `FUNCTIONAL`, por lo que no se anotaron retardos `specify` ni SDF.
  No se empleó GDSII.

Para instanciar simultáneamente RTL y puertas, `prepare_netlist.py` crea una
copia de prueba y renombra solamente el módulo superior a `asic_top_gate`. El
netlist original de LibreLane permanece intacto.

## Programa y estímulos

El entregable `sw/game_asic_100ns.s` no fue modificado (SHA-256
`6a50ad33d7b620d08f24539a74e137be3a44b8288baefdb52da13c7c5d1f0164`).
`prepare_program.py` genera una copia exclusiva para simulación y sustituye de
forma comprobada:

- espera inicial: 30 000 000 → 300 ciclos;
- ciclos por décima: 1 000 000 → 100 ciclos.

El control del juego, el cálculo del promedio y las diez rondas se conservan.
El assembler genera 141 palabras, usadas tanto por el RTL como por el netlist.
La ROM de prueba tiene SHA-256
`4bd6f23b0f78662dddfc5a442fc44e639e5780a2e65a7d21243247ca85704b32`.

El testbench libera reset después de ocho ciclos, confirma los cuatro LEDs de
calentamiento, espera 360 ciclos y pulsa un botón para comenzar. Después prueba
primero el error y posteriormente diez aciertos. Para acelerar la simulación se
inyecta el mismo vector, en el mismo ciclo, a la salida del debouncer de ambas
implementaciones. La lógica del debouncer no se valida en esta prueba; no se
modificó el RTL para efectuar el bypass.

## Implementación reproducible

Archivos de soporte:

- `tests/stage7/stage7_tb.v`: testbench y comparación ciclo a ciclo.
- `tests/stage7/prepare_program.py`: copia acelerada no entregable.
- `tests/stage7/prepare_netlist.py`: copia del netlist con top renombrado.
- `tests/stage7/compare_logs.py`: comparación automática de registros.
- `asic/rom_ram_stage7_sim.json`: síntesis específica de la imagen acelerada.

Desde WSL, en la raíz del repositorio:

```sh
# Generar programa y obtener un netlist nuevo con un tag no usado.
make stage7-synth ETAPA7_TAG=etapa7_rom_ram_post_synth_repro

# Compilar, ejecutar dos veces, producir VCD/logs y comparar.
make stage7-run ETAPA7_TAG=etapa7_rom_ram_post_synth_repro
```

Para repetir exactamente la corrida conservada:

```sh
make stage7-run ETAPA7_TAG=etapa7_rom_ram_post_synth \
  PDK_ROOT="$HOME/.ciel"
```

Se usó Icarus Verilog 12.0 estable. La compilación terminó sin errores ni
módulos faltantes. El modelo completo GF180 emite advertencias sobre módulos no
instanciados y Icarus avisa que un `force` procedural evalúa su RHS una vez; el
testbench reaplica deliberadamente el `force` en cada cambio de botón.

## Evidencia

- Log RTL/cosimulación: `tests/stage7/evidence/rtl.log`.
- Log post-síntesis/cosimulación: `tests/stage7/evidence/post_synth.log`.
- Comparación automática: `tests/stage7/evidence/comparison.txt`.
- Log de compilación: `tests/stage7/evidence/compile.log`.
- Ondas: `tests/stage7/evidence/rtl.vcd` y `post_synth.vcd`.
- Log original de síntesis:
  `asic/runs/etapa7_rom_ram_post_synth/06-yosys-synthesis/yosys-synthesis.log`.
- Métricas de síntesis: `06-yosys-synthesis/state_out.json`.

GTKWave 3.3.116 está instalado y los VCD pueden abrirse con:

```sh
gtkwave tests/stage7/evidence/rtl.vcd
gtkwave tests/stage7/evidence/post_synth.vcd
```

No se generó una captura: la sesión disponible no tenía un servidor gráfico o
un capturador virtual para automatizarla. Los VCD reales sí quedaron guardados.

## Limitaciones pendientes

- La simulación es funcional a retardo cero; no comprueba retardos post-route,
  setup/hold ni las violaciones eléctricas pendientes de la Etapa 6B.
- La equivalencia observada cubre estas tres secuencias, no todo el espacio de
  estados como lo haría una verificación formal.
- El debouncer se omite únicamente en el estímulo acelerado.
- No se declara cierre físico ni GDSII final.

