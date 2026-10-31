# Etapa 22: rendimiento y cobertura gate-level

## Duracion del programa ASIC

`sw/game_asic_100ns.s` usa `CICLOS_3S = 30 000 000` y diez rondas. El
periferico ASIC usa `DebounceCycles = 100000`. A 100 ns por ciclo, cada espera
de tres segundos son 30 millones de ciclos y cada debounce son 10 ms.

Estimaciones conservadoras, sin contar la variacion de la respuesta humana ni
las instrucciones de entrada/salida:

| Escenario | Esperas principales | Orden de ciclos |
|---|---:|---:|
| Ronda correcta | warm-up + una espera de ronda + debounce | ~60,4 millones |
| Boton incorrecto | warm-up + espera de ronda + espera de error + debounce | ~90,4 millones |
| Diez rondas | warm-up + diez esperas de ronda + diez debounces | ~330,4 millones |

El banco externo no modifica registros internos ni reduce estos contadores.

## Benchmark medido

Se ejecutaron 100000 ciclos RTL, 1000 ciclos gate-level y 1000 ciclos pareados
sin VCD. Resultados observados:

| Modo | Ciclos | Tiempo real | Tasa aproximada | Mismatches |
|---|---:|---:|---:|---:|
| RTL | 100008 | 5,32 s | 18 798 ciclos/s | 0 |
| Gate-level | 1008 | 4,30 s | 234 ciclos/s | n/a |
| RTL + gate pareado | 1008 | 4,42 s | 228 ciclos/s pareados | 0 |

Con la tasa gate-level medida, una ronda correcta requeriria del orden de 3
dias, el caso incorrecto unos 4,5 dias y diez rondas aproximadamente 16 dias.
Son extrapolaciones de rendimiento, no ejecuciones de esos escenarios.

## Estado de equivalencia

La prueba externa anterior de 208 ciclos y el benchmark pareado de 1008 ciclos
terminaron con cero diferencias en LEDs, displays y SPI. No se ejecutaron las
tres escenas completas porque su costo gate-level medido es prohibitivo en el
entorno disponible. Por tanto, no se declara equivalencia funcional completa
del juego.

Evidencias: `tests/stage22/stage22_benchmark_tb.v`,
`tests/stage22/run_benchmark.sh`, `reports/stage22/*_run.log`,
`reports/stage22/*_time.txt` y `reports/stage22/paired1000_*`.
