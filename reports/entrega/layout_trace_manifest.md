# Manifiesto de trazabilidad física — Etapa 21

Fecha de verificación: 2026-11-01.

## Archivos locales recibidos para la revisión

| Archivo | Tamaño | SHA-256 |
|---|---:|---|
| `asic_top.def` | 7.977.974 bytes | `76e0b0e9c3777d736a549b070b84d8173b5941edd3c3ae38fac66df9ac084a05` |
| `asic_top.nl.v` | 1.785.965 bytes | `45e5749e9731ee6babf7ce6a8dad56a6dd5885d007fea9762436c58031972da2` |

## Cruce con artefactos versionados

- El netlist local `asic_top.nl.v` tiene Git blob SHA-1 `ae5b3a632a3b2c9aa12a09fabfc4700f4a0e8c88`, idéntico al blob de `reports/entrega/etapa21_combined_final.nl.v`. Por tanto, su contenido es byte a byte el mismo que el netlist post-PnR publicado para Etapa 21.
- El DEF local declara `UNITS DISTANCE MICRONS 2000` y `DIEAREA (0,0)-(1207860,1243700)`, equivalente a `603,93 × 621,85 µm).
- Las métricas versionadas de `reports/entrega/etapa21_combined_metrics.json` informan `design__die__bbox = 0.0 0.0 603.93 621.85`. La geometría del DEF concuerda exactamente con el bounding box del die de Etapa 21.
- El GDSII `reports/entrega/etapa21_combined.gds` está versionado por separado.

## Extracción de bloques

Con el netlist y DEF se identificaron:
- Register file: 480 flip-flops, por la jerarquía `g_asic_regfile.u_rf.bank_a`.
- Contador `cycle_q`: 32 flip-flops, por la señal `u_periph.cycle_q`.
- Frontera observable de ALU: 32 drivers de `g_rom_ram_memory.u_ram.a_addr_i[ ]`. Debido al aplanamiento de jerarquía, estos drivers no representan el contorno completo ni todas las celdas internas de la ALU.

Las coordenadas se convierten desde DBU a micrones dividiendo por 2000. La tabla agregada está en `reports/stage21/layout_trace_coordinates.csv`.

## Límite de la verificación

El DEF recibido para esta revisión no está almacenado en GitHub junto al GDSII; por ello no es posible comparar su hash con el DEF original de la corrida archivada. La asociación con Etapa 21 queda corroborada por la identidad exacta del netlist, la coincidencia del DIEAREA con las métricas y la correspondencia de instancias/señales. No se declara una prueba criptográfica directa del DEF contra el directorio original `asic/runs/etapa21_combined`.
