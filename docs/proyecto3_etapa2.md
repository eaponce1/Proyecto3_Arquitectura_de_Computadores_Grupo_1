# Proyecto 3 — Etapa 2: arquitecturas de memoria ASIC

## Uso real de memoria

El ensamblado actual de `sw/game.s` contiene **143 instrucciones de 32 bits**
(572 bytes); la última está en `0x238`. El juego usa una sola palabra de datos
fuera de MMIO: `2044(x0)` = `0x000007FC`, usada para conservar el resto
fraccional del promedio. Los demás accesos `lw/sw` son MMIO: display `+0`,
LEDs `+4`, botones `+8`, ciclos `+12` y marca de LED `+16` sobre
`0x80000000`.

`pochoco_ram.v` tiene dos puertos con respuesta registrada: instrucción y
datos aparecen al siguiente flanco. Las alternativas preservan esa latencia:
la tabla ROM se evalúa combinacionalmente, pero las salidas hacia Espino se
registran. El SoC distingue datos de periféricos con `data_addr[31]`; la RAM
solo recibe solicitudes con ese bit en cero.

## Implementaciones

| Selección | Módulo | Programa | Datos | Reset/inicialización |
| --- | --- | --- | --- | --- |
| `MemoryArchitecture=1` | `pochoco_memory_rom_ram` | `game_rom`, `case` combinacional de 143 palabras | Un registro de 32 bits en `0x7FC`, escritura por byte | ROM queda en lógica; dato y respuestas se resetean a cero |
| `MemoryArchitecture=2` | `pochoco_memory_unified_ff` | Un arreglo de FFs de 144 palabras | Última palabra del mismo arreglo | Copia las 143 palabras desde ROM tras reset, borra el dato y mantiene el SoC en reset hasta terminar |

La arquitectura unificada traduce internamente la dirección lógica `0x7FC` a
su última palabra física. Así conserva el binario y mapa del juego, pero no
reserva las 512 palabras de un mapa físico contiguo.

## Generación e integración

`sw/assembler.py` ahora implementa `generar_rom_verilog()` y permite:

```text
python sw/assembler.py sw/game.s -o sw/game.hex \
  --verilog-rom rtl/game_rom.v
```

`rtl/game_rom.v` se genera automáticamente y no usa `initial` ni
`$readmemh`. `make asic-rom` lo regenera. `asic_top` selecciona la alternativa
con su parámetro público, cuyo valor predeterminado es 1:

```verilog
asic_top #(.MemoryArchitecture(1)) u_rom_ram (...);
asic_top #(.MemoryArchitecture(2)) u_unified_ff (...);
```

`pochoco_soc` mantiene `MemoryArchitecture=0` como ruta FPGA original. Para
las dos opciones ASIC, `espino_core` selecciona `espino_register_file_ff` en
lugar del register file con `SB_RAM40_4K`. Este register file conserva dos
puertos síncronos y se resetea a cero.

## Archivos creados o modificados

* Creados: `rtl/game_rom.v`, `rtl/pochoco_memory_rom_ram.v`,
  `rtl/pochoco_memory_unified_ff.v`, `rtl/espino_core/espino_register_file_ff.v`,
  `tests/test_asic_memory.py`, `tests/asic_game_smoke_tb.v` y este documento.
* Modificados: `sw/assembler.py`, `rtl/espino_core/espino_core.v`,
  `rtl/pochoco_soc.v`, `rtl/asic_top.v`, `Makefile` y el generado `sw/game.hex`.
* No se modificó `sw/game.s`: conserva diez rondas y sus constantes de tiempo.

## Verificaciones reales

En WSL con Python e Icarus Verilog:

* `python3 -B tests/run_tests.py`: **14/14 pruebas pasaron**. Las tres nuevas
  comprueban las 143 palabras, igualdad exacta ROM/assembler, el único dato
  no-MMIO y ausencia de `SB_RAM40_4K`, `$readmemh` e `initial` en la memoria
  ASIC.
* Pasaron las simulaciones RTL existentes de core, periféricos, SPI y decoder.
* `asic_game_smoke_tb` pasó con arquitecturas 1 y 2. Verifica que el core sale
  del reset, ejecuta la ROM del juego y entra al warm-up con LEDs `4'hf`.
  Se elaboró sin `tests/ram_model.v`, por lo que las configuraciones ASIC no
  requieren el modelo de la primitiva iCE40.
* Las pruebas funcionales de `test_game.py` pasan y validan diez rondas,
  pulsación errónea/reinicio, promedio, saturación y timeout. Son un modelo
  acelerado del programa, no una simulación RTL completa de esperas de 3 s.

Icarus reportó advertencias existentes sobre módulos sin unidad de tiempo;
no reportó errores de elaboración ni de ejecución.

## Pendiente

No se ejecutó LibreLane/GF180MCU, síntesis, STA, DRC, floorplan ni P&R. Por
tanto quedan pendientes métricas reales de área, flip-flops, utilización y
frecuencia máxima, además de la comparación física entre ambas alternativas.
