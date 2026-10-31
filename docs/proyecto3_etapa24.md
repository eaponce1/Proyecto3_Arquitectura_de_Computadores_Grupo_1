# Etapa 24 — diagnostico de Verilator

## Entorno

Dentro de WSL Ubuntu, `which verilator` resolvia accidentalmente al wrapper
Windows `/mnt/c/Tools/oss-cad-suite/bin/verilator`. Ese wrapper intentaba
ejecutar `verilator_bin` sin `.exe`. La version Windows directa es Verilator
5.053 devel, pero buscaba sus archivos internos en `/yosyshq/share/verilator`.

Ubuntu ofrece el paquete `verilator` 5.020-1. La instalacion global quedo
bloqueada por autenticacion sudo y fue cancelada sin modificar WSL, Yosys,
LibreLane, Docker ni el PDK.

Se extrajo el paquete 5.020-1 de forma aislada en `/tmp/verilator520`, sin
instalarlo globalmente. Tras preparar un enlace local para `verilator_bin` y
su archivo waiver, el ejecutable Ubuntu funciono.

## Modelos GF180

Los modelos usados por Icarus existen sin cambios en:

`/home/edu_ponce/.ciel/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog/`

Incluyen `primitives.v` y `gf180mcu_fd_sc_mcu7t5v0.v`.

## Resultados

Verilator 5.020 compilo y ejecuto el RTL durante 100000 ciclos en 0,03 s,
con `mismatches=0` (aproximadamente 3,3 millones de ciclos/s). Evidencia:
`reports/stage24/verilator_rtl_build.log`,
`reports/stage24/verilator_rtl_run.log` y
`reports/stage24/verilator_rtl_time.txt`.

Con los modelos GF180 reales, Verilator rechazo la sintaxis UDP y las
strength specifications de la biblioteca. El log es
`reports/stage24/verilator_gate_lint_ubuntu.log`. Sin los modelos, el netlist
no resuelve sus modulos de celdas GF180; usar blackboxes impediria una
simulacion funcional. Por tanto, no se ejecuto Verilator gate-level.

La tasa Icarus gate-level medida en Etapa 22 sigue siendo aproximadamente
234 ciclos/s. No se iniciaron escenarios de cientos de millones de ciclos.

## Equivalencia formal

Yosys puede leer estructuralmente el netlist con celdas blackbox, pero no hay
SymbiYosys instalado ni un mapeo secuencial preparado entre RTL, registros
aplanados, memoria, reset y celdas GF180. No se declara equivalencia formal.

## Conclusion

Verilator es viable para RTL, pero no para el netlist final con los modelos
GF180 disponibles. La equivalencia observable completa del juego sigue
pendiente; solo estan respaldadas las pruebas gate-level cortas de Etapas 21 y
22 con Icarus.
