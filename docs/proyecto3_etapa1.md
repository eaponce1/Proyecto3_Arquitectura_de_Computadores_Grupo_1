# Proyecto 3 — Etapa 1: adaptación inicial de FPGA a ASIC

## Alcance de esta etapa

Esta etapa agrega una envoltura para ASIC y separa el reset de la lógica
específica de arranque de la FPGA. No modifica `sw/game.s`, el assembler, la
funcionalidad del juego ni las arquitecturas de memoria. Tampoco se eliminó
ningún archivo del Proyecto 2.

## Copia del proyecto inspeccionada

La descarga contiene dos árboles llamados `pochoco_soc-main`. El árbol usado
para esta etapa es el que contiene `rtl/espino_core/` y todos los fuentes del
Proyecto 2:

```text
Proyecto-2_Juego-en-Assembly-main/
  Proyecto-2_Juego-en-Assembly/
    Proyecto-2_Juego-en-Assembly/
      pochoco_soc-main/
```

El otro árbol (`../../pochoco_soc-main` respecto de este directorio) no
contiene `rtl/espino_core/` y por tanto no es una fuente completa del diseño.
No se ha eliminado ni modificado esa copia.

## Arquitectura actual

* `rtl/game_top.v` es el top de la FPGA Go Board. Conserva los puertos físicos
  y el retraso de encendido de 2048 ciclos que se utilizaba en el Proyecto 2.
* `rtl/asic_top.v` es el nuevo top exclusivo para ASIC. Sus puertos lógicos son
  `clk_i`, `rst_ni`, `btn_i[3:0]`, `leds_o[3:0]`, `seg1_n_o[6:0]`,
  `seg2_n_o[6:0]`, `spi_sclk_i`, `spi_mosi_i`, `spi_cs_n_i` y `spi_miso_o`.
  `rst_ni` es externo y activo en bajo. `seg*_n_o` conserva la polaridad
  activa-baja de las salidas del Proyecto 2; los bits `[0:6]` corresponden a
  segmentos `A:G`.
* `rtl/pochoco_soc.v` conecta el núcleo `espino_core` (`u_core`), la RAM
  unificada (`u_ram`), periféricos (`u_periph`) y SPI (`u_spi`). El reset se
  recibe ahora por `i_Rst_ni`.
* `rtl/espino_core/espino_core.v` instancia explícitamente el banco de
  registros `u_rf`, la ALU dentro de `u_id.u_alu`, la etapa IF, la etapa ID,
  la LSU y el controlador. Esos nombres e instancias se mantienen.
* `rtl/pochoco_periph.v` contiene el contador libre `cycle_q` y el contador
  capturado al escribir LEDs `led_cycle_q`, además de botones, LEDs y displays.
* `sw/game.s` y `sw/assembler.py` se revisaron como parte de la estructura,
  pero no se modificaron. `game.hex` sigue siendo la imagen de programa usada
  por defecto.

## Archivos creados y modificados

| Archivo | Cambio |
| --- | --- |
| `rtl/asic_top.v` | Nuevo wrapper ASIC sin restricciones ni pines de FPGA. Instancia `pochoco_soc` y pasa el reset externo activo-bajo. |
| `rtl/pochoco_soc.v` | Añadido puerto `i_Rst_ni`. Eliminado el contador de power-on reset interno, específico de iCE40, y distribuido el reset externo existente a los submódulos. |
| `rtl/game_top.v` | Se conserva como top FPGA. El contador de power-on reset de 2048 ciclos se movió aquí y alimenta `i_Rst_ni`, conservando el comportamiento de arranque previo. |
| `docs/proyecto3_etapa1.md` | Este documento. |

## Reset

El ASIC debe suministrar un reset externo activo-bajo a `asic_top.rst_ni` y
mantenerlo asertado durante la inicialización del chip. Los registros del PC,
la validez de IF/ID, la LSU, el estado de lectura MMIO, periféricos, contador
de ciclos, botones sincronizados/debounced y SPI ya tienen reset asíncrono
activo-bajo y ahora reciben ese reset externo.

El retraso de 2048 ciclos se mantiene solamente en `game_top.v`, donde la
inicialización de `por_cnt` depende del comportamiento de configuración de la
FPGA. No está en la jerarquía iniciada por `asic_top`.

## Dependencias e incompatibilidades ASIC identificadas

1. **Primitiva iCE40 en el register file:**
   `rtl/espino_core/espino_register_file.v` instancia cuatro bloques
   `SB_RAM40_4K` (dos copias de `espino_regbank32`, cada una con mitades alta y
   baja). Esta primitiva no existe en GF180MCU/LibreLane. El archivo de prueba
   `tests/ram_model.v` es solo un modelo de simulación, no una macro ASIC.
2. **Inicialización de programa:** `rtl/pochoco_ram.v` usa
   `initial` y `$readmemh(MemFile, mem)`. Es conveniente para simulación y
   síntesis FPGA, pero no inicializa automáticamente SRAM estándar ASIC. La
   ruta relativa `sw/game.hex` también deberá incorporarse explícitamente al
   flujo de implementación ASIC.
3. **RAM inferida:** `pochoco_ram` describe una matriz de registros de dos
   puertos lógicos con lectura síncrona y escritura por byte. La inferencia de
   RAM que hacía la FPGA no garantiza una macro SRAM GF180 equivalente. Esta
   sustitución queda para la Etapa 2.
4. **Estado sin reset en memorias:** el register file no usa `rst_ni`, y la
   matriz/las salidas de `pochoco_ram` tampoco tienen reset. En el FPGA se
   apoya en la inicialización de la primitiva y de `$readmemh`; en ASIC su
   estado después de reset no queda definido. No se alteró esa arquitectura
   porque corresponde a la siguiente etapa de memoria.
5. **Dependencias de placa:** `goboard.pcf`, `Makefile` (`synth_ice40`,
   `nextpnr-ice40`, `icepack`, `iceprog`), los nombres de puertos de
   `game_top.v` y la inversión de displays son integración de la Go Board.
   `asic_top.v` no usa PCF ni asignaciones físicas.
6. **Supuestos temporales:** el debounce de botones está fijado a 10 ms para
   25 MHz (`249999` ciclos), y el SPI se sincroniza contra ese mismo reloj.
   La frecuencia final ASIC debe respetar o recalcular ese valor en una etapa
   posterior.

Por estas razones no se declara todavía compatibilidad con LibreLane ni la
existencia de un GDSII.

## Verificaciones realizadas

Ejecutado desde este directorio:

```text
python -B tests/run_tests.py
```

Resultado real:

* Las 11 pruebas Python pasaron: assembler y lógica/modelo del juego
  (`Ran 11 tests ... OK`).
* En Windows la suite informó inicialmente que faltaban `iverilog` y `vvp`.
  Se comprobó que WSL sí incluye `/usr/bin/iverilog`, `/usr/bin/vvp` y
  `/usr/bin/yosys`, y se volvió a ejecutar la suite en WSL.
* En WSL pasaron las simulaciones RTL de `core`, `periph`, `spi` y `decoder`;
  sus bancos de prueba imprimieron respectivamente `PASS core`, `PASS
  peripherals`, `PASS SPI` y `PASS decoder`. La suite también elaboró
  `game_top` correctamente como su última comprobación.
* Se elaboró específicamente el nuevo top ASIC sin salida de error:

  ```text
  iverilog -g2012 -Wall -s asic_top -o /tmp/asic_top.vvp \
    rtl/*.v rtl/espino_core/*.v tests/ram_model.v
  ```

  `tests/ram_model.v` se incluyó únicamente para modelar la primitiva iCE40
  durante simulación/elaboración; no demuestra compatibilidad ASIC.
* No se ejecutó síntesis, floorplan, place-and-route ni DRC de LibreLane/GF180.
  Por ello no se infiere éxito de síntesis ASIC ni compatibilidad con LibreLane.

## Pendiente antes de la Etapa 2

* Elegir e implementar las dos arquitecturas de memoria solicitadas,
  reemplazando tanto `SB_RAM40_4K` como la dependencia de `$readmemh` para el
  caso ASIC.
* Definir la estrategia de carga del programa y la inicialización/estado del
  register file y la RAM tras reset.
* Instalar o proporcionar las herramientas de simulación y el entorno
  LibreLane con PDK GF180MCU, y después elaborar/sintetizar específicamente
  `asic_top`.
* Definir frecuencia objetivo y, si cambia respecto de 25 MHz, revisar el
  debounce y el comportamiento temporal del juego.
