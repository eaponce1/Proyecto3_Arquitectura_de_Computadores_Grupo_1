# Preparación de entrega del Proyecto 3

## Estado y selección

La referencia **reglamentaria** es `etapa9_rom_ram_util40_debounce`
(CLOCK_PERIOD=100 ns, FP_CORE_UTIL=40 %): 2695 slew, 10 capacitancia y
58 fanout. La mejor candidata **técnica** es
`etapa12_rom_ram_no_delay_ss` con los mismos 100 ns y 40 %:
440/2/57. Los experimentos de Etapa 13 dieron 410/3/57
(post-GRT) y 468/1/0 (CTS). La corrida `etapa21_combined` posteriormente
alcanzó slew/capacitancia/fanout 0/0/0 con setup y hold positivos en nueve
corners; su GDSII y metrics están seleccionados para la entrega. El cierre
corresponde al macro bajo las restricciones disponibles, no a un chip
completo con pads e I/O.
La comparación completa y sus fuentes están en
`docs/proyecto3_etapa12.md`, `docs/proyecto3_etapa13.md`,
`reports/stage12/comparison.csv` y `reports/stage13/comparison.csv`.

El código y los resultados históricos no se han eliminado ni sustituido.
El árbol original `asic/runs/` ocupa aproximadamente 33,5 GiB y permanece
**local**; el `.gitignore` evita subir sus ODB, DEF, SPEF y demás
intermedios. El paquete GitHub previsto incluye `rtl/`, `sw/`,
`asic/` (salvo `asic/runs/`), `scripts/`, `tests/`,
`reports/`, `docs/`, `Makefile`, el README y las restricciones FPGA.
El informe Overleaf es `docs/Proyecto3_Overleaf.zip`.

## Evidencia esencial seleccionada para GitHub

En `reports/entrega/<tag>/` se copiaron, sin editar, los
`metrics.json` y los reportes originales de STA/electricidad
`checks.rpt`, `ws.*.rpt`, `wns.*.rpt` y `tns.*.rpt` para
`max_ss_125C_4v50` y `max_ff_n40C_5v50` de las cuatro corridas.
Las tablas de los **nueve corners** siguen en
`reports/stage12/timing_nine_corners.csv` y
`reports/stage13/timing_nine_corners.csv`. Los logs originales de
lanzamiento y algunos volcados voluminosos permanecen localmente en
`reports/stage12/` y `reports/stage13/`; se excluyen de Git por tamaño
o porque registran rutas personales de instalación. Los reportes
seleccionados y los datos comparativos sí se incluyen. Los logs de
KLayout externo están en sus subdirectorios
`klayout_no_delay_ss/` y `klayout_drc_etapa9_util40/`.
La evidencia RTL/post-síntesis está en `tests/stage7/evidence/`,
incluidos logs, VCD y comparación automática.
La comparación de los dos logs preservados se volvió a ejecutar y dejó
`reports/entrega/stage7_comparison_recheck.txt` con 13 registros por lado
y `exact_match=true`. **No** se volvió a ejecutar el binario VVP:
`reports/entrega/stage7_rtl_recheck.log` conserva el error exacto
`VVP input file 12.0 can not be run with run time version 14.0 (devel)`.
Para repetir la simulación completa hay que recompilar el testbench con
una versión de Icarus compatible y los modelos Verilog GF180MCU; el
original de Etapa 7 permanece en `tests/stage7/evidence/`.

Los GDSII seleccionados son **candidatos**, no diseños con signoff:

| Archivo copiado | Corrida | SHA-256 |
|---|---|---|
| `reports/entrega/etapa9_rom_ram_util40_debounce.gds` | Reglamentaria | `cf5373fe5b882d3f31242c36f44958881b44b544b1ddf0ebb2858a36ee2b01f6` |
| `reports/entrega/etapa12_rom_ram_no_delay_ss.gds` | Mejor técnica previa | `bd78dab33b34b2773eadc4ea550e48b38a0a63bdac12bce0aa2a854b97e9fa7b` |
| `reports/entrega/etapa21_combined.gds` | Cierre eléctrico del macro | `be7de4cbba159c5e296f37e33b8d75f14f6ea0d8bb70763d5ba8610eac903f85` |

Los originales permanecen en
`asic/runs/<tag>/final/gds/asic_top.gds`. Para comparar:
`sha256sum reports/entrega/*.gds` y
`sha256sum asic/runs/<tag>/final/gds/asic_top.gds`.
La evidencia adicional de la corrida cerrada incluye
`reports/entrega/etapa21_combined_metrics.json`,
`reports/entrega/etapa21_combined_klayout.lyrdb`, el netlist final
`reports/entrega/etapa21_combined_final.nl.v` (hash igual al original) y los SPEF en
`asic/runs/etapa21_combined/final/spef/`. También se conserva la copia
adaptada para simulación en `reports/entrega/etapa21_combined_gate.nl.v` y
el diagnóstico de compilación en `reports/entrega/stage21_gate_compile.log`;
el testbench histórico requiere jerarquía interna que el netlist aplanado no
mantiene, por lo que esa limitación no se presenta como equivalencia nueva.
Los reportes completos de cada paso del flujo solo están en el árbol
local ignorado, por lo que **GitHub por sí solo no contendrá todos los
logs originales**. Quien necesite auditoría paso a paso debe recibir
ese árbol por un medio de almacenamiento separado.

### Validación funcional final

La comparación externa de Etapa 21 cubrió 208 ciclos con
`mismatches=0`. El benchmark RTL/gate-level pareado cubrió 1008 ciclos con
`mismatches=0` en LEDs, displays y SPI. Icarus gate-level ejecuta cerca de
234 ciclos/s; por ello no se ejecutaron las esperas completas de 30 millones
de ciclos, el caso de botón incorrecto ni las diez rondas en el netlist final.
Verilator 5.020 aceleró el RTL, pero no pudo analizar los modelos GF180MCU
por sus UDP y strength specifications. No se declara equivalencia funcional
exhaustiva ni formal.

Las evidencias seleccionadas de las Etapas 21--24 incluyen los logs y scripts
pequeños en `reports/entrega/`, además de las fuentes completas en
`tests/stage21/`, `tests/stage22/`, `tests/stage23/` y `reports/stage24/`.

## Reproducción mínima desde WSL

Seguir los requisitos de Docker, LibreLane 3.0.16 y GF180MCU descritos en
`README.md`. Usar la ruta WSL sin espacios verificada en ese archivo y
etiquetas **nuevas** para no pisar evidencia.

~~~sh
make asic-rom
make asic-rom-100ns
python3 -B tests/run_tests.py
make asic-stage4-check
make asic-synth-rom-ram ROM_RAM_SYNTH_TAG=entrega_synth_rom
make asic-synth-unified-ff UNIFIED_SYNTH_TAG=entrega_synth_ff
make stage7-synth ETAPA7_TAG=entrega_stage7
make stage7-run ETAPA7_TAG=entrega_stage7
make stage9-regulatory ETAPA9_TAG=entrega_rom_100ns_util40
~~~

La corrida de Etapa 12 se puede repetir con
`python3 scripts/stage12_run.py asic/rom_ram_stage12_no_delay_ss.json
--tag entrega_stage12_ss`; las de Etapa 13 se describen en
`docs/proyecto3_etapa13.md`. Estos flujos son costosos y **no fueron
repetidos durante esta preparación**. No se requieren nuevas corridas
físicas para revisar las tablas y evidencias ya conservadas.

## Auditoría final ejecutada en esta preparación

- `python -B tests/run_tests.py`: **16 pruebas Python correctas** y
  seis testbenches Icarus con PASS. Cubren ambas memorias, generación de
  ROM, programa ASIC, diez rondas, promedio, periféricos y procesador.
- Revisión de rutas: presentes `rtl/pochoco_memory_rom_ram.v`,
  `rtl/pochoco_memory_unified_ff.v`, `sw/game.s`,
  `sw/assembler.py`, `asic/generated/game_rom.v` y ambas
  configuraciones ASIC. No se editó ninguno de estos archivos.
- La regeneración desde Assembly está cubierta por
  `test_100ns_program_matches_generated_hardware_and_fpga_differences`
  y `test_game_size_and_generated_rom_contents`, ambas correctas.
  Los targets del README y los lanzadores de Etapas 12/13 existen;
  **no** se volvió a ejecutar LibreLane.
- Comparación de los logs originales RTL/post-síntesis:
  13 registros por lado y coincidencia exacta. La simulación completa
  no pudo repetirse con el VVP local por incompatibilidad de versión
  del binario precompilado (12 frente a 14); ver el error conservado
  en `reports/entrega/stage7_rtl_recheck.log`.
- La versión documentada en
  `reports/stage12/signoff_no_delay_ss.json` es LibreLane 3.0.16,
  PDK `gf180mcuD` revisión
  `8afc8346a57fe1ab7934ba5a6056ea8b43078e71` y biblioteca
  `gf180mcu_fd_sc_mcu7t5v0`. No se hizo una nueva inspección del
  entorno WSL: aquí `wsl --status` respondió `E_ACCESSDENIED`.
- Los dos GDSII copiados existen y sus SHA-256 coinciden con los
  originales. Los estados DRC/LVS/antena y eléctricos son los de
  los reportes preservados, no de verificaciones físicas nuevas.
- `python scripts/package_overleaf.py` generó un ZIP de ocho archivos
  con `main.tex` en la raíz, bibliografía y figuras PDF/PNG. El CRC
  del ZIP pasó; no hay pdfLaTeX/BibTeX local, por lo que **no se
  afirma compilación del PDF actualizado**.

## Pendientes antes de publicar

1. Revisar la selección con el profesor: si exige logs completos de
   LibreLane, entregar `asic/runs/` aparte por su tamaño.
2. Descargar de Overleaf un PDF compilado con la versión actual del
   informe y colocarlo en `docs/informe_proyecto3.pdf` si se desea
   incluir el PDF; no hay PDF local verificado en esta copia.
3. Crear un repositorio remoto nuevo o acordar con el dueño si se
   reutilizará el del Proyecto 2. Git local está inicializado en
   `main`, pero no tiene remoto, staging, commits ni pushes. El
   repositorio público anterior
   `https://github.com/Guille805/Proyecto-2_Juego-en-Assembly`
   corresponde al proyecto base; la conexión disponible solo tiene
   permiso de lectura. Revisar `git status` y el tamaño antes de
   cualquier commit.
4. Mantener visible el estado de signoff pendiente: las violaciones
   eléctricas y la ausencia de SDC de interfaz ASIC específica.

## Auditoría Git local para GitHub

Se inicializó un repositorio local vacío en la carpeta principal, rama
`main`. No hay remoto configurado ni archivos en staging, commits o
pushes. El repositorio público anterior
`https://github.com/Guille805/Proyecto-2_Juego-en-Assembly`
contiene el README y el comienzo de `pochoco_soc-main/sw/game.s`
del Proyecto 2 conservados aquí; corresponde al proyecto base.
La conexión GitHub disponible informa lectura, pero no escritura.
Se recomienda un repositorio remoto nuevo para no alterar Proyecto 2,
salvo acuerdo del grupo y permisos confirmados.

`git ls-files --others --exclude-standard` informa **753 archivos
seleccionados, 39,15 MiB sin compresión**. El archivo mayor es
`reports/entrega/etapa12_rom_ram_no_delay_ss.gds` (9,05 MiB).
Se incluyen los **36 archivos** de `reports/entrega/`. El PDF
actualizado **no existe** en este workspace; no está en la selección.
El código LaTeX y el ZIP autocontenido sí están.

El `.gitignore` excluye los 33,5 GiB de `asic/runs/`, entornos Python,
cachés, binarios de simulación, auxiliares LaTeX, productos FPGA
regenerables, volcados grandes de violaciones, un VCD experimental
de Etapa 10 y ciertos logs originales con rutas locales. Ninguno
de esos archivos se eliminó. La búsqueda de patrones de credenciales,
claves privadas y rutas personales en la selección no dio coincidencias;
esto no sustituye la revisión humana antes de publicar.

Según los límites oficiales de GitHub, los objetos Git individuales
de más de 100 MiB se rechazan y un push no puede superar 2 GiB:
https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits
Los archivos seleccionados están por debajo de ambos límites. El
repo tampoco contiene aún un PDF final; ese es el bloqueo principal
para cumplir íntegramente la lista de entrega solicitada.

## Comandos preparados (ejecutar solo después de la revisión)

Desde la carpeta principal, como el usuario propietario de los archivos:

~~~sh
git status --short
git check-ignore -v asic/runs/etapa12_rom_ram_no_delay_ss/final/gds/asic_top.gds
git add .
git diff --cached --stat
git diff --cached --check
git status --short
~~~

Después de comprobar que el PDF actualizado está incluido, que no hay
secretos y que el listado staged es el esperado, **solo con autorización**:

~~~sh
git commit -m "Entrega Proyecto 3: ASIC Pochoco SoC y evidencias"
git remote add origin <URL_DEL_NUEVO_REPOSITORIO>
git push -u origin main
~~~

No usar la URL de Proyecto 2 sin acuerdo del grupo y permiso de escritura.
No se ejecutó ninguno de los comandos de staging, commit, remote o push
de este bloque.
