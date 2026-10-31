# Proyecto 3 - Etapa 16: diagnostico de slew y ECO localizado

## Referencia y metodologia

La referencia es `etapa15_eco_combined`, con CLOCK_PERIOD=100 ns,
FP_CORE_UTIL=40 %, arquitectura ROM+RAM, GF180MCU D y biblioteca
`gf180mcu_fd_sc_mcu7t5v0`. Se conservaron todas las corridas anteriores. No se
modificaron RTL, `game.s`, el assembler, la ISA ni las diez rondas.

El STA se leyo desde los nueve `checks.rpt` de
`asic/runs/etapa15_eco_combined/13-openroad-stapostpnr/<corner>/`, despues de
RCX. Cada grupo SS tiene SPEF post-route en
`asic/runs/etapa15_eco_combined/12-openroad-rcx/{nom,min,max}/`. No se usaron
wire-load para las metricas finales.

## Distribucion de las violaciones de la referencia

El analisis encontro **447 pines unicos en 71 redes**. Como cada pin aparece en
los tres corners SS (`nom_ss`, `min_ss`, `max_ss`), los reportes contienen 852
apariciones. Estas cantidades no son 852 redes distintas.

La clasificacion se hizo recorriendo el netlist fisico hacia los drivers y
excluyendo pines de reloj/reset al recorrer el cono. El resultado por
apariciones fue:

| Cono de origen | Apariciones | Observacion |
|---|---:|---|
| Instruccion/ROM/fetch | 578 | Incluye decodificacion y selectores posteriores a la instruccion registrada |
| Mixto datos/register-file e instruccion | 235 | Conos compartidos de `rs1`/`rs2`, multiplexores y datos |
| Reset | 39 | Redes internas de reset; no son puertos externos violados |
| Reloj | 0 | CTS ya tenia fanout=0 |
| Puertos externos | 0 | No hay pines de interfaz entre los violadores |

La clasificacion es topologica del netlist y no una medicion de area por
modulo. El reporte completo reproducible esta en
`reports/stage16/slew_violations.csv`; el agrupamiento por red, driver, celda,
corner y severidad esta en `reports/stage16/slew_by_net.csv`.

## Diez redes principales

El limite de slew Liberty/SDC usado por el checker es 3 ns. Los conteos de la
tabla son apariciones de pines en los tres corners SS; por eso no deben
interpretarse como numero de redes.

| Red | Apariciones | Driver y celda | Peor slew (ns) | Exceso (ns) |
|---|---:|---|---:|---:|
| `net804` | 33 | `fanout804/Z`, `buf_1` | 4,402678 | 1,402678 |
| `_2333_` | 33 | `_5832_/ZN`, `nand2_1` | 3,627904 | 0,627904 |
| `net943` | 33 | `fanout943/Z`, `buf_1` (tambien `_5813_/S`, `mux2_2`) | 3,481839 | 0,481839 |
| `_2700_` | 30 | `_6231_/ZN`, `nand2_1` | 3,568727 | 0,568727 |
| `a_rdata_o[7]` | 30 | `_8474_/Q`, `dffrnq_1` | 3,566988 | 0,566988 |
| `net300` | 24 | `fanout300/Z`, `buf_1` | 4,803723 | 1,803723 |
| `data_wdata[4]` | 24 | `_9249_/Q`, `dffrnq_1` | 4,570990 | 1,570990 |
| `data_wdata[0]` | 24 | `_9245_/Q`, `dffrnq_1` | 3,571486 | 0,571486 |
| `a_rdata_o[21]` | 22 | `_8488_/Q`, `dffrnq_1` | 3,319428 | 0,319428 |
| `_1029_` | 22 | `_4414_/Z`, `and2_1` | 3,245530 | 0,245530 |

Estas diez redes suman 244 apariciones, pero el residual esta distribuido en
71 redes y muchos tipos de celda. Los drivers mas frecuentes entre los pines
violados son `buf_1` (171), `nand2_1` (120), `nor2_1` (81), `mux2_2` (53) y
`nand3_1` (52). Esto descarta que una sola red ROM sea la causa unica.

Las señales `a_rdata_o`, `data_wdata` y los conos asociados al register file
confirman que el problema esta principalmente despues del registro de
instruccion, en decodificacion, selectores y distribucion de operandos. No hay
un arbol de reloj residual que reparar en esta referencia.

## Alternativas consideradas

1. **Buffers/sizing fisico dirigido.** Es seguro para la funcionalidad, pero
   exigiría actuar sobre decenas de redes; puede aumentar area y degradar hold.
2. **Duplicacion RTL.** No se implemento: la sintesis actual no demuestra que
   preserve duplicacion controlada para estos conos y podria aumentar area.
3. **Reestructuracion de multiplexores/register file.** Requeriria una
   modificacion estructural amplia y nueva equivalencia ciclo a ciclo; queda
   documentada como trabajo posterior, no como cambio improvisado.
4. **Drivers GF180 mayores.** Se probaron buffers legales `buf_2` mediante ECO;
   no se cambiaron limites Liberty ni restricciones SDC.

## Experimento controlado

Se preservo `etapa15_eco_combined` y se inserto un `buf_2` en el driver de cada
una de las cinco redes con mas apariciones: `net804`, `_2333_`, `net943`,
`_2700_` y `a_rdata_o[7]`. La configuracion es
`asic/rom_ram_stage16_eco_top5.json`; la corrida es
`etapa16_eco_top5`. Se reanudo desde el ODB de detailed routing de la etapa 15,
se reruteo, se extrajeron SPEF nuevos y se ejecuto STA en nueve corners.

| Metrica | Etapa 15 | Etapa 16 top-5 |
|---|---:|---:|
| Slew | 447 | **377** |
| Capacitancia | 0 | 0 |
| Fanout | 0 | 0 |
| Area stdcell (um2) | 186096 | 186184 |
| Utilizacion real | 53,6205 % | 53,6458 % |
| Setup WS minimo (ns) | +52,436311 | +52,474723 |
| Hold WS minimo (ns) | +0,010453 | +0,010312 |
| Routing DRC | 0 | 0 |
| Magic DRC | 0 | 0 |
| LVS | 0 | 0 |
| Antena | 0 | 0 |

La ECO elimina 70 apariciones de slew (447 a 377 como conteo maximo por
corner), pero no consigue slew cero. El margen de hold empeora ligeramente,
por lo que no se considera una candidata de signoff.

## Verificaciones y artefactos

La corrida termina con codigo 0, genera SPEF en
`asic/runs/etapa16_eco_top5/12-openroad-rcx/` y GDSII en
`asic/runs/etapa16_eco_top5/final/gds/asic_top.gds`. Routing DRC, Magic DRC,
LVS, antena, XOR e IR-drop terminaron sin errores reportados. KLayout DRC fue
omitido porque `KLAYOUT_DRC_RUNSET` no esta configurado para gf180mcuD; el deck
externo aun no se ha ejecutado sobre esta corrida.

El peor residual de slew de la nueva corrida es 4,803081 ns en `net300` en
`max_ss_125C_4v50`. Los nueve corners conservan WNS/TNS=0/0 para setup y hold;
el peor hold real es +0,010312 ns en `max_ff_n40C_5v50`.

`python -B tests/run_tests.py` se ejecuto nuevamente: 16 pruebas Python y seis
testbenches Icarus pasaron. Como no se modifico RTL, esta verificacion confirma
la funcionalidad del diseño fuente; no constituye una simulacion SDF del ECO.

## Estado de cierre

**No se consiguio cierre electrico completo.** La ECO top-5 mejora el slew, pero
377 violaciones siguen distribuidas en 65 redes. Resolverlas mediante buffers
individuales requeriria una intervencion mucho mas amplia, con riesgo de area,
congestion y hold. Una reestructuracion RTL del register file/multiplexores
seria aun mas invasiva y debe especificarse y verificarse antes de implementarla.
El GDSII de Etapa 16 es un candidato experimental, no un GDSII con signoff:
faltan slew cero y KLayout DRC externo.

No se modifico el informe LaTeX, no se borraron corridas y no se hicieron
commits ni pushes.
