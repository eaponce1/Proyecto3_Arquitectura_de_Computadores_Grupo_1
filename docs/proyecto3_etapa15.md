# Proyecto 3 - Etapa 15: ECO post-route con parasiticos reales

Fecha: 26 de octubre de 2026. Esta etapa conserva intactas las corridas de las
Etapas 9, 12, 13 y 14. No se modificaron RTL, `sw/game.s`, el assembler, las
diez rondas, las restricciones Liberty ni la SDC.

## Metodo y compatibilidad

Se utilizo LibreLane 3.0.16 en Docker (`ghcr.io/librelane/librelane:3.0.16`),
OpenROAD commit `dcf36133a369abc8f3c5e5738cd4d82e4903c0e0`, GF180MCU D y
`gf180mcu_fd_sc_mcu7t5v0`, con `CLOCK_PERIOD=100` ns, `FP_CORE_UTIL=40` y
`MemoryArchitecture=1`.

El procedimiento sigue el mecanismo ECO documentado oficialmente por LibreLane:
reanudar con `--with-initial-state` desde el `state_out.json` de
`OpenROAD.DetailedRouting`, inyectar `Odb.InsertECOBuffers` mediante
`meta.substituting_steps`, ejecutar el rerouting incremental, RCX y STA. La
referencia es <https://librelane.readthedocs.io/en/stable/usage/using_ecos.html>.
No se reutilizo el intento de Etapa 14: aquel cargaba el ODB sin parasiticos y
producia el warning de wire-load `GRT-0300` antes de reparar.

La ECO de esta etapa si genero SPEF post-route nuevo: cada corrida contiene tres
SPEF bajo `asic/runs/<tag>/12-openroad-rcx/{nom,min,max}/` y nueve reportes de STA
en `13-openroad-stapostpnr/<corner>/`. La advertencia `GRT-0300` del paso ECO
solo indica que el router incremental no dispone de timing para priorizar redes;
no se utilizo para aprobar el resultado. Las metricas finales se tomaron despues
de RCX.

## Diagnostico usado

La referencia CTS de Etapa 13 tenia 468 slew, 1 capacitancia y 0 fanout. Las
violaciones de datos mas severas incluian `_1548_`, conducida por `_4966_/Z`
(`or2_1`), y `net860`, conducida por `fanout860/Z` (`buf_1`). Las violaciones
de fanout y las capacitancias de reloj ya habian sido eliminadas por la variante
CTS; por ello no se altero el reloj. La causa residual es carga/transicion de
conos combinacionales de datos, no una construccion `$readmemh` ni un puerto
externo.

## Experimentos reproducibles

Cada experimento se inicio desde el mismo ODB de la corrida
`etapa13_rom_ram_cts_retry/45-openroad-detailedrouting/state_out.json`, salvo
el segundo, que comenzo desde el resultado detailed-routing del primer ECO para
probar una segunda insercion sobre el mismo driver. Cada configuracion conserva
los archivos fuente de la baseline y solo cambia `INSERT_ECO_BUFFERS`.

| Intento | Configuracion | ECO | Slew | Cap. | Fanout | Area stdcell (um2) | Util. real | Setup WS min (ns) | Hold WS min (ns) | DRC/Magic/LVS/antena |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| E1 | `rom_ram_stage15_eco_1548.json` | 1 `buf_2` en `_4966_/Z` | 458 | 0 | 0 | 186078 | 53.6154 % | +52.435735 | +0.010453 | 0/0/0/0 |
| E2 | `rom_ram_stage15_eco_1548_twobuf.json` | 2 `buf_2` en `_4966_/Z` | 458 | 0 | 0 | 186113 | 53.6256 % | +52.435714 | +0.010453 | 0/0/0/0 |
| E3 | `rom_ram_stage15_eco_net860.json` | 1 `buf_2` en `fanout860/Z` | 457 | 2 | 0 | 186078 | 53.6154 % | +52.436069 | +0.010453 | 0/0/0/0 |
| E4 | `rom_ram_stage15_eco_combined.json` | 1 buffer en cada red | **447** | **0** | **0** | 186096 | 53.6205 % | **+52.436311** | **+0.010453** | 0/0/0/0 |

Los conteos son el maximo entre los nueve corners. En E4, por corner, el slew
fue 258 (nom_ss), 147 (min_ss) y 447 (max_ss); los otros corners dieron cero.
La capacitancia y el fanout fueron cero en todos los corners de E4. El peor
slew de E4 se observa en `max_ss_125C_4v50`; `checks.rpt`, linea 285, muestra
`fanout287/I` con 4.803723 ns frente al limite de 3 ns. E4 no alcanza cero
slew y por tanto no es cierre.

## Timing y verificaciones fisicas de E4

Los nueve corners de E4 tienen WNS/TNS de setup y hold iguales a 0/0 (el WNS
de LibreLane es el slack negativo, truncado a cero). Los peores slacks positivos
reales son setup +52.436311 ns en `max_ss_125C_4v50` y hold +0.010453 ns en
`max_ff_n40C_5v50`. El detalle completo esta en
`asic/runs/etapa15_eco_combined/13-openroad-stapostpnr/`.

El flujo completo termino con codigo 0 en los cuatro intentos. En E4:

- detailed routing: cero errores finales (`route__drc_errors=0`);
- Magic DRC: cero (`magic__drc_error__count=0`);
- LVS: cero (`design__lvs_error__count=0`);
- antena: cero redes y pines violadores;
- XOR de layout: limpio;
- IR drop: VDD y VSS conectados, con worst-case drop reportado de 0.000185 V
  y 0.000128 V, respectivamente;
- KLayout DRC interno fue omitido porque `KLAYOUT_DRC_RUNSET` no esta definido
  para gf180mcuD. Esto no se presenta como aprobacion KLayout. El deck externo
  de Etapa 9 no fue rerun para estos ECO.

E4 genero `asic/runs/etapa15_eco_combined/final/gds/asic_top.gds` (9,859,742
bytes). Es un GDSII candidato con DRC/Magic/LVS/antena limpios, pero no un GDSII
con signoff: aun quedan 447 violaciones de slew y KLayout externo no fue
revalidado en esta corrida.

## Validacion funcional

Ningun ECO cambio RTL ni el programa; los buffers solo modifican la base fisica.
Se repitio `python -B tests/run_tests.py`: 16 pruebas Python y seis
testbenches Icarus pasaron (`OK`, todos los `PASS`). Esta evidencia confirma la
baseline funcional; no equivale a una simulacion SDF de cada netlist ECO.

## Comandos y logs

Desde WSL, en `/tmp/pochoco3`:

```sh
docker run --rm --user 1000:1000 \
  -v /tmp/pochoco3:/tmp/pochoco3 \
  -v /home/edu_ponce/.ciel:/home/edu_ponce/.ciel \
  -e PDK_ROOT=/home/edu_ponce/.ciel -e HOME=/tmp -w /tmp/pochoco3 \
  ghcr.io/librelane/librelane:3.0.16 python3 -m librelane \
  --manual-pdk --docker-no-tty --condensed --hide-progress-bar -j 4 \
  --run-tag etapa15_eco_combined \
  --with-initial-state asic/runs/etapa13_rom_ram_cts_retry/45-openroad-detailedrouting/state_out.json \
  --from odb.insertecobuffers asic/rom_ram_stage15_eco_combined.json
```

Logs de lanzamiento y pasos se conservaron directamente en
`asic/runs/etapa15_eco_1548/`, `asic/runs/etapa15_eco_1548_twobuf/`,
`asic/runs/etapa15_eco_net860/` y `asic/runs/etapa15_eco_combined/`.
Cada carpeta contiene `COMMANDS`, `state_out.json`, logs de ECO/rerouting, RCX,
STA y los checkers; no se sobrescribio ningun resultado anterior.

## Conclusion

La ECO post-route oficial es reproducible y usa parasiticos SPEF reales. La
combinacion E4 es la mejor de esta etapa: elimina completamente capacitancia y
fanout y reduce el slew de 468 a 447 respecto de la base CTS. No elimina el
slew residual, por lo que no hay cierre electrico completo. Tampoco es valido
promover el GDSII a definitivo. La siguiente intervencion justificada seria
una estrategia de reparacion/reestructuracion de los conos de datos restantes
(por ejemplo, segmentacion controlada de cargas o sizing guiado por RC en
varias redes), seguida de otro ECO con STA post-route y KLayout externo; no se
ejecuta en esta etapa.
