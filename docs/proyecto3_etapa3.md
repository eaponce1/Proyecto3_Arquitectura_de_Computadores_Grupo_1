# Proyecto 3 — Etapa 3: preparación de LibreLane

## Entorno comprobado

| Componente | Resultado real |
| --- | --- |
| WSL2 | Kernel Linux `6.6.87.2-microsoft-standard-WSL2`; la consulta `wsl -l -v` desde Windows devolvió `E_ACCESSDENIED`, así que no se comprobó el estado de todas las distribuciones. |
| Python | Windows 3.13.3; WSL 3.12.3. No se detectó un entorno virtual de LibreLane. |
| Yosys | WSL `/usr/bin/yosys`, versión 0.33. |
| Icarus | WSL `/usr/bin/iverilog`, operativo en `make asic-check`. |
| Docker | Cliente Windows 29.7.2; el daemon no responde (`docker_engine` no existe). Docker Desktop indica que la integración WSL no está habilitada. |
| LibreLane | No se detectó el paquete/comando en WSL. Versión y variables de la instalación aún no verificadas. |
| GF180MCU | No se detectó un PDK en las rutas WSL revisadas. Revisión Open_PDKs/Volare no disponible. |
| OpenROAD | No se detectó en WSL. |

## Configuraciones

`asic/rom_ram.json` y `asic/unified_ff.json` son configuraciones independientes
de `asic_top`. Ambas fijan `CLOCK_PORT=clk_i`, `CLOCK_PERIOD=100` ns y
`FP_CORE_UTIL=40`. La primera usa `SYNTH_PARAMETERS=["MemoryArchitecture=1"]`
y la segunda `MemoryArchitecture=2`. Incluyen exclusivamente fuentes de la
jerarquía ASIC; no incluyen `pochoco_ram.v`, `game_top.v` ni el register file
con `SB_RAM40_4K`.

El enunciado se refiere a la familia **GF180MCU**. LibreLane/Open_PDKs suelen
identificar la variante concreta mediante `gf180mcuD`; por eso se configuró
`PDK=gf180mcuD` y `STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0`. La biblioteca
es una opción documentada de GF180MCU, pero su presencia y compatibilidad
con la revisión local aún deben validarse cuando se instale el PDK. Si el
curso exige literalmente `PDK=gf180mcu`, habrá que confirmar qué nombre
acepta la instalación antes de correr el flujo.

Las variables `VERILOG_FILES`, `SYNTH_PARAMETERS`, `CLOCK_PORT`,
`CLOCK_PERIOD` y `FP_CORE_UTIL` aparecen en la documentación oficial de
LibreLane. Su aceptación por una versión local sigue pendiente de comprobación.

## Revisión de sintetizabilidad

`asic_top` expone `clk_i`, `rst_ni`, 4 botones, 4 LEDs, 14 segmentos y 4
señales SPI. El register file ASIC es `espino_register_file_ff`, con dos
bancos de 16×32 bits para las lecturas síncronas. `game_rom.v` se regenera
desde `sw/game.s` con `make asic-rom`; la imagen contiene 143 instrucciones.

Las configuraciones ASIC excluyen la primitiva iCE40 y la RAM FPGA con
`initial/$readmemh`. La ROM y ambas memorias ASIC tampoco usan esas
construcciones. Icarus elaboró los dos tops sin módulos faltantes usando
exactamente la lista de fuentes ASIC. Aún falta comprobar blackboxes y
advertencias de síntesis con el Yosys empaquetado por LibreLane.

## Comandos reproducibles

Desde la raíz de `pochoco_soc-main` dentro de WSL:

```sh
make asic-rom
make asic-check
make asic-synth-rom-ram
make asic-synth-unified-ff
```

Para ejecutar posteriormente el flujo físico completo:

```sh
make asic-full-rom-ram
make asic-full-unified-ff
```

Los tags de corrida separan los resultados en `asic/runs/etapa3_rom_ram`,
`asic/runs/etapa3_unified_ff`, `asic/runs/etapa3_full_rom_ram` y
`asic/runs/etapa3_full_unified_ff` según el directorio de diseño de LibreLane.
Cada corrida debe conservar sus logs, reportes, netlist y `resolved.json`
originales. Esas carpetas **aún no existen**.

## Instalación pendiente

Según la [guía Docker de LibreLane](https://librelane.readthedocs.io/en/stable/installation/docker_installation/index.html),
primero hay que iniciar Docker Desktop y habilitar la integración con la
distribución WSL. Después, en WSL:

```sh
docker version
docker run hello-world
python3 -m venv .venv
. .venv/bin/activate
python -m pip install librelane
python -m librelane --dockerized --smoke-test
```

Si se usa ese entorno virtual, invocar los targets con `LIBRELANE='python -m
librelane --dockerized'` y con el entorno activado. LibreLane/Volare deben
instalar o habilitar la variante `gf180mcuD`; comprobar después
`$PDK_ROOT/gf180mcuD`, su archivo de revisión y la biblioteca
`gf180mcu_fd_sc_mcu7t5v0`. No se ha ejecutado ninguna instalación.

## Resultados y cambios

`make asic-check` pasó para ambas arquitecturas con Icarus, sin errores ni
warnings. Se crearon las dos configuraciones y se añadieron targets al
`Makefile`. No se alteró el juego, el assembler ni el RTL funcional.

## Actualización: instalación y primeras síntesis reales (22-10-2026)

Esta sección reemplaza el estado provisional de instalación y resultados
indicado arriba. Desde WSL se verificó: Docker cliente/servidor **29.7.2**,
`docker info` con servidor operativo, `docker run hello-world` exitoso y
Python **3.12.3**. Se instaló `python3.12-venv` en Ubuntu y LibreLane
**3.0.16** en `.venv-librelane-stage3`. El smoke test oficial
`python -m librelane --dockerized --smoke-test` terminó con
`Smoke test passed.` (usa SKY130 como diseño de ejemplo).

Ciel habilitó GF180MCU revisión Open_PDKs
`8afc8346a57fe1ab7934ba5a6056ea8b43078e71` en
`~/.ciel/gf180mcuD`. Se verificó la biblioteca exacta
`gf180mcu_fd_sc_mcu7t5v0`, incluida su vista Liberty. La versión de Yosys
dentro de LibreLane es **0.62** (`7326bb7d6641500ecb285c291a54a662cb1e76cf`).
LibreLane 3.0.16 aceptó ambas configuraciones JSON, sus parámetros de
elaboración, el reloj de 100 ns y la selección de PDK/SCL.

La ruta Windows contiene un espacio en `Edu Ponce`. Una primera corrida de
Yosys/ABC falló con `ABC: Cannot open file "/mnt/c/Users/Edu"`. Para ejecutar
sin alterar los fuentes, se montó temporalmente el mismo directorio del
proyecto en WSL como `/tmp/pochoco3` y se usó `--manual-pdk` para seleccionar
la revisión Ciel habilitada. La primera invocación dockerizada sin terminal
falló con `cannot attach stdin to a TTY-enabled container because stdin is
not a terminal`; se corrigió con `--docker-no-tty`. Desde el alias:

```sh
cd /tmp/pochoco3
make asic-synth-rom-ram
make asic-synth-unified-ff
```

Los targets actuales usan el entorno virtual y `--docker-no-tty
--dockerized --manual-pdk`. El alias es un montaje temporal: tras reiniciar
WSL se debe recrear antes de repetir las corridas. Ambos targets finalizaron
con `Flow complete`. La corrección RTL necesaria fue cambiar la extensión
de `digit_q` de 28 a 24 ceros en `rtl/pochoco_periph.v`; el valor de 32 bits
leído por software es idéntico, y se eliminó el warning `WIDTHTRUNC`.

| Arquitectura | Área de celdas sintetizadas (µm²) | FF mapeados | Celdas | Sin mapear | Warnings lint |
| --- | ---: | ---: | ---: | ---: | ---: |
| ROM + RAM | 140802.3232 | 874 | 4722 | 0 | 16 |
| Unificada FF | 565735.9680 | 5317 | 17443 | 0 | 16 |

Los FF se sumaron por tipo `__dff*` en `stat.rpt`. Ambos `state_out.json`
indican `synthesis__check_error__count=0`. Los 16 warnings restantes son
principalmente señales o parámetros no usados en la configuración ASIC;
no se silenciaron. La fuente original de las métricas y los logs está en:

* `asic/runs/etapa3_rom_ram_v2/06-yosys-synthesis/reports/stat.rpt`
* `asic/runs/etapa3_rom_ram_v2/06-yosys-synthesis/yosys-synthesis.log`
* `asic/runs/etapa3_unified_ff_v2/06-yosys-synthesis/reports/stat.rpt`
* `asic/runs/etapa3_unified_ff_v2/06-yosys-synthesis/yosys-synthesis.log`

Estas cifras son únicamente de síntesis. No se ejecutó floorplan, P&R,
STA ni el flujo físico del proyecto; utilización y frecuencia máxima siguen
sin medir.
