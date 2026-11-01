# Estado de entrega — Proyecto 3

## Entrega y alcance

La entrega de GitHub y la defensa presencial están fijadas para el **4 de noviembre de 2026 a las 10:30**, según el enunciado. El resultado del proyecto es un **macro digital ASIC**, no un chip completo listo para encapsular.

El repositorio contiene RTL, Assembly y assembler, configuraciones ASIC, scripts, pruebas, reportes seleccionados, el informe LaTeX y el PDF compilado:
- Informe fuente: `docs/informe_proyecto3/main.tex`.
- Bibliografía y figuras: `docs/informe_proyecto3/`.
- Paquete Overleaf: `docs/Proyecto3_Overleaf.zip`.
- PDF publicado: `docs/informe_proyecto3.pdf`.

## Estado técnico de la corrida final

La corrida seleccionada para cierre eléctrico es `etapa21_combined`, basada en ROM+RAM, con `CLOCK_PERIOD=100 ns` y `FP_CORE_UTIL=40`. La evidencia consolidada está en `reports/entrega/etapa21_combined_metrics.json`, el netlist final y el GDSII seleccionado.

| Métrica | Resultado reportado |
|---|---:|
| Violaciones slew / capacitancia / fanout | **0 / 0 / 0** |
| Setup WNS mínimo (nueve corners) | **+53,053929 ns** |
| Hold WNS mínimo (nueve corners) | **+0,006720 ns** |
| Routing DRC | **0** |
| Magic DRC | **0** |
| LVS | **0 errores** |
| Antena | **0 redes infractoras** |
| XOR de equivalencia del flujo | **0 diferencias** |
| Área de die | **0,375554 mm²** |
| Área stdcell | **187808 µm²** |
| Utilización | **54,1139 %** |

KLayout DRC no se ejecutó como paso integrado de LibreLane porque no está definido `KLAYOUT_DRC_RUNSET` para gf180mcuD. Se ejecutó externamente el deck GF180MCU y el reporte `reports/stage21_etapa21_combined.lyrdb` no contiene errores. El cierre corresponde al macro bajo las restricciones disponibles: no incluye pad ring, ESD ni modelos de I/O, y no se definieron SDC específicos de interfaz ASIC. Por tanto, no debe describirse como signoff de un chip completo.

## Revisión de los requisitos del enunciado

### 3.1 — Adaptación FPGA a ASIC
El repositorio incluye `rtl/asic_top.v`, configuración ASIC y documentación de las diferencias de reset, reloj y memoria. Para la defensa conviene ubicar en los logs originales los warnings/errores concretos del flujo que motivaron cada reemplazo; no todos esos logs completos están versionados en GitHub.

### 3.2 — Memorias y programa
Se implementan las dos alternativas:
- ROM combinacional generada desde Assembly más RAM de datos reducida.
- Memoria unificada implementada con flip-flops.

La comparación de área, cantidad de FF y utilización está en el informe. La Etapa 25 completó un barrido de 100 a 60 ns con STA post-route en nueve corners. El menor período demostrado que cumple setup y hold es 64 ns (15,625 MHz); 63 ns falla setup (WNS −0,210036 ns; TNS −0,821011 ns). Los puntos de 62 y 60 ns también fallan. El límite queda acotado entre 63 y 64 ns para los períodos ensayados; no se afirma una frecuencia máxima matemática. La memoria unificada conserva violaciones eléctricas (10758/730/355 slew/capacitancia/fanout) y no sustituye el cierre eléctrico ROM+RAM de Etapa 21. Evidencia: `reports/stage25/unified_ff_frequency_sweep_final.md` y `.csv`.

### 3.3 — Síntesis y jerarquía
El informe incluye las cinco celdas estándar más usadas, desglose jerárquico de register file, ALU, ROM, periférico y SoC, y el método previo al aplanamiento. El register file es el mayor contribuyente de área.

### 3.4 — Timing
La arquitectura ROM+RAM se barrió a 100, 70, 62 y 60 ns. El menor período demostrado que cierra los nueve corners es 62 ns (16,129 MHz); a 60 ns falla setup. Se documentan la ruta crítica, la variante RTL experimental descartada y el cálculo de constantes del juego para 100 ns. Cada período puede inducir una nueva optimización, placement y buffering.

### 3.5 — Floorplan, PDN, placement y costo
Se comparan utilizaciones objetivo de 30 %, 40 % y 50 %, se documenta la red de alimentación y se estima el costo lineal a partir del área del die. La aproximación no representa el costo real de fabricación, yield, máscaras, encapsulado ni pruebas.

### 3.6 — Signoff y layout
Los reportes de Etapa 21 respaldan DRC, LVS y antena limpios para el macro. El layout final debe distinguirse de las capturas experimentales de etapas anteriores. **La evidencia de ubicación anotada de register file, ALU y contador sobre el layout exacto de `etapa21_combined` queda pendiente de confirmar**; no se debe presentar una captura de otra corrida como si fuera la final.

### 3.7 — Simulación funcional post-síntesis
La evidencia de Etapa 21 compara 208 ciclos por interfaz externa, con cero diferencias; el benchmark pareado compara 1008 ciclos de LEDs, displays y SPI, también con cero diferencias. No se ejecutaron en el netlist final las esperas completas, el caso de botón incorrecto ni las diez rondas, debido al costo de simulación gate-level. El repositorio conserva pruebas RTL y evidencia histórica de Etapa 7, pero la repetición de esa simulación se vio limitada por incompatibilidad entre la versión del binario VVP y la disponible. **No se declara equivalencia exhaustiva ni formal del juego completo en el netlist final.**

## Evidencia y reproducibilidad

El árbol completo `asic/runs/` (aprox. 33,5 GiB según la auditoría local previa) no se publica en GitHub por tamaño. GitHub contiene una selección de métricas, reportes, GDSII y netlist en `reports/entrega/`; los logs e intermedios originales completos deben conservarse localmente y compartirse por separado si el profesor los solicita.

Comandos básicos desde WSL, en la raíz del repositorio:

```sh
make asic-rom
make asic-rom-100ns
python3 -B tests/run_tests.py
make asic-stage4-check
make stage9-regulatory ETAPA9_TAG=entrega_rom_ram_100ns_util40
```

Para LibreLane se documenta la versión **3.0.16**, PDK **gf180mcuD**, revisión de open_pdks `8afc8346a57fe1ab7934ba5a6056ea8b43078e71`, y biblioteca **gf180mcu_fd_sc_mcu7t5v0**. Docker Desktop debe estar iniciado, WSL integrado y el PDK correctamente instalado. Usar etiquetas nuevas para no sobrescribir corridas previas.

## Pendientes reales antes de la defensa

1. Incorporar o confirmar una captura anotada del layout de `etapa21_combined` con register file, ALU y contador. La figura actual corresponde a Etapa 6 y no debe presentarse como layout final.
2. Tener disponibles localmente los logs completos de `asic/runs/` para responder preguntas de trazabilidad; el árbol completo no se publica por su tamaño.
3. Compilar el PDF actualizado y revisar visualmente tablas, referencias cruzadas, figuras y portada antes de entregar.
4. Mantener explícitas las limitaciones de SDC de interfaz y de equivalencia funcional exhaustiva/formal del netlist final.

No se modificaron RTL, Assembly, assembler, constraints ni resultados de corridas físicas al preparar esta documentación.
