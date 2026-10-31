# Estado de la comparacion funcional Etapa 21

## Auditoria del banco historico

`tests/stage7/stage7_tb.v` accedia a `u_pochoco_soc`, `u_core`,
`u_asic_regfile`, `u_rf.bank_a[8]`, `digit_q` y `btn_q` mediante referencias
jerarquicas y `force`. El log `reports/entrega/stage21_gate_compile.log`
conserva el error de elaboracion de esas referencias. El netlist final declara
unicamente el modulo plano `asic_top_gate`.

## Banco nuevo

`tests/stage21/stage21_external_tb.v` y
`tests/stage21/run_external_compare.sh` usan solamente los puertos externos:
clock, reset, botones, LEDs, displays y SPI. El reset `rst_ni` es activo bajo
en RTL y netlist. Se utiliza `asic/generated/game_rom.v` y los modelos reales
de `gf180mcu_fd_sc_mcu7t5v0`.

## Ejecucion realizada

El script se ejecuto desde WSL Ubuntu y compilo el RTL y el netlist final sin
errores. Icarus produjo 56 advertencias del modelo de celdas (wires implicitos
y unidades de tiempo), pero ningun error de elaboracion.

Resultado:

```
PASS|stage21_external_smoke|cycles=208|button_cycles=8|mismatches=0
```

Evidencias:

- `reports/stage21/stage21_external_compile.log`;
- `reports/stage21/stage21_external_compare.log`;
- `reports/stage21/stage21_external.vcd`;
- `tests/stage21/stage21_external.vvp`.

La comprobacion independiente de sintaxis RTL tambien paso con Icarus.
La suite Python no se presenta como sustituto de esta prueba gate-level.

## Cobertura pendiente

La prueba ejecutada cubre reset, reposo, un pulso externo de boton y
comparacion ciclo a ciclo de las salidas observables durante 208 ciclos.

Las escenas de ronda correcta, boton incorrecto y diez rondas no se marcaron
como pasadas. El programa ASIC espera 30 000 000 ciclos (3 s a 100 ns) antes
de la primera seleccion y el periferico filtra botones durante 100000 ciclos.
El banco historico aceleraba esto mediante jerarquia interna eliminada en el
netlist; repetir esa manipulacion no seria una comparacion valida del netlist
final. Se requiere una simulacion externa larga adicional para cubrirlas.
