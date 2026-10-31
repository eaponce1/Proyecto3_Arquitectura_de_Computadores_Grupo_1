# Etapa 23 — validación funcional eficiente

## Herramientas

WSL dispone de Icarus Verilog 12.0 y Yosys 0.33. `sby` no está instalado.
Existe Verilator 5.053 devel en `C:\Tools\oss-cad-suite`, pero su binario
portable no es utilizable directamente en esta instalación: busca
`verilated_std.sv` y `verilated_std_waiver.vlt` en `/yosyshq/share/verilator`,
ruta que no existe. El log está en `reports/stage23/verilator_gate_lint.log`.

Además, el netlist final contiene celdas GF180 (antenna, fill y standard
cells) cuyos modelos Verilog están disponibles en Ciel para Icarus, pero no se
encuentran en una ruta Windows utilizable por este binario de Verilator. Por
eso no se declaró una simulación Verilator gate-level.

## Benchmark reproducible

El banco `tests/stage22/stage22_benchmark_tb.v` se reutilizó sin cambiar RTL
ni netlist. Se midieron:

| Modo | Ciclos | Tiempo | Diferencias |
|---|---:|---:|---:|
| RTL | 100008 | 5,32 s | 0 |
| Gate-level | 1008 | 4,30 s | 0 en modo gate aislado |
| RTL + gate pareado | 1008 | 4,42 s | 0 |

La tasa gate-level es aproximadamente 234 ciclos/s. Por tanto, la duración
estimada sigue siendo del orden de días para una ronda completa y semanas para
diez rondas. No se iniciaron simulaciones de cientos de millones de ciclos.

## Equivalencia formal

Yosys pudo leer estructuralmente el netlist aplanado como `asic_top_gate` con
sus celdas tratadas como black boxes (`reports/stage23/yosys_gate_probe.log`).
Esto solo verifica sintaxis y jerarquía del netlist. No es equivalencia
secuencial: no existe SymbiYosys, el RTL contiene una imagen ROM distinta de
la representación de celdas y no se preparó un mapeo formal de estados,
reset, memoria y celdas GF180.

## Resultado

La prueba externa de Etapa 21 y el benchmark pareado corto siguen dando cero
diferencias observables. No se cubrieron mediante gate-level los escenarios
de ronda correcta, botón incorrecto y diez rondas, y no se declara equivalencia
funcional completa. El impedimento concreto es el costo medido de Icarus y la
instalación incompleta/incompatible de Verilator, no una modificación del
diseño.
