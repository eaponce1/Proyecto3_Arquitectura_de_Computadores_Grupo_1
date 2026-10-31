# Etapa 21: comparación por interfaz externa

`stage21_external_tb.v` compara el RTL `asic_top` y el netlist aplanado
`asic_top_gate` únicamente mediante `clk_i`, `rst_ni`, `btn_i`, las salidas de
LED/display y `spi_miso_o`. No contiene referencias jerárquicas al register
file, al periférico ni a nombres generados por Yosys.

La imagen RTL utilizada es `asic/generated/game_rom.v`, generada desde
`sw/game_asic_100ns.s`; esta es la imagen ASIC de 100 ns que corresponde al
netlist final. Los modelos son los Verilog de
`gf180mcu_fd_sc_mcu7t5v0` suministrados por Ciel.

Ejecutar desde la raíz del repositorio:

```sh
tests/stage21/run_external_compare.sh
```

El banco aplica reset activo bajo, 64 ciclos de reposo, un pulso externo de
botón de 8 ciclos y 128 ciclos adicionales. La prueba es una comparación de
salidas observables y no pretende declarar que se completó una ronda: el
netlist final contiene el debounce ASIC de 100000 ciclos y el programa espera
30 000 000 ciclos (3 s a 100 ns) antes de la primera selección. Por ello, las
pruebas histórica de ronda correcta, pulsación incorrecta y diez rondas no se
pueden acelerar mediante jerarquía eliminada sin dejar de ser una comparación
del netlist final.

Ejecucion verificada: `PASS|stage21_external_smoke|cycles=208|button_cycles=8|mismatches=0`.
Las tres escenas completas del juego permanecen fuera de cobertura porque
requieren la simulacion larga con los tiempos ASIC reales.
