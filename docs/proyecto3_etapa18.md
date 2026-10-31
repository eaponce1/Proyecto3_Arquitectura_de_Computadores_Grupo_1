# Proyecto 3 — Etapa 18: cierre progresivo de slew

## Alcance

Se conservaron RTL, Assembly, la imagen de memoria y todas las corridas previas. Los experimentos se realizaron sobre estados post-route de `etapa17_group3`, con `CLOCK_PERIOD=100 ns`, `FP_CORE_UTIL=40`, GF180MCU-D y `gf180mcu_fd_sc_mcu7t5v0`. Cada grupo insertó cinco `gf180mcu_fd_sc_mcu7t5v0__buf_2`, relegalizó, reruteó, extrajo RCX/SPEF y ejecutó STA post-route en nueve corners.

## Diagnóstico actualizado

El diagnóstico de `etapa17_group3` (`reports/stage18/` y `scripts/stage16_diagnose.py`) encontró 248 pines únicos, 351 apariciones y 48 redes físicas con slew fuera de límite. Las violaciones aparecen en los corners SS (`max_ss_125C_4v50`, `min_ss_125C_4v50`, `nom_ss_125C_4v50`). Las redes no están concentradas en un único driver: aparecen buffers de distribución, lógica combinacional de instrucción/ROM y salidas del register file/RAM.

Las redes más repetidas al inicio de la etapa fueron `net286`, `data_wdata[6]`, `data_wdata[5]`, `_2750_`, `_1427_`, `net360`, `_2796_`, `_2878_` y `net936`. Las primeras reparaciones de la Etapa 17 ya habían intervenido los drivers asociados con `net300`, `net1237`, `net271`, `net1342` y varios conos de instrucción; no se repitieron deliberadamente en este diagnóstico.

## Resultados de los cuatro grupos

| Estado | Drivers intervenidos | Slew | Cap. | Fanout | Área stdcell | Utilización | Setup mínimo (ns) | Hold mínimo (ns) |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| Etapa 17 group3 | referencia | 248 | 0 | 0 | 186447 | 0.537217 | 52.602908 | 0.010302 |
| Etapa 18 group1 | `fanout286/Z`, `_9251_/Q`, `_9250_/Q`, `_6283_/ZN`, `_4812_/ZN` | 227 | 0 | 0 | 186535 | 0.537470 | 52.572042 | 0.008394 |
| Etapa 18 group2 | `_4887_/ZN`, `fanout360/Z`, `_6330_/ZN`, `_6415_/ZN`, `fanout936/Z` | 194 | 0 | 0 | 186623 | 0.537723 | 52.575897 | 0.009748 |
| Etapa 18 group3 | `fanout983/Z`, `fanout798/Z`, `fanout824/Z`, `_6824_/ZN`, `_8476_/Q` | 140 | 0 | 0 | 186711 | 0.537976 | 52.530128 | 0.009396 |
| Etapa 18 group4 | `_7183_/ZN`, `_7045_/ZN`, `_7118_/ZN`, `_8489_/Q`, `_9028_/Q` | **127** | 0 | 0 | 186798 | 0.538229 | 52.419752 | 0.009199 |

El grupo 4 es el mejor resultado: elimina 121 de las 248 violaciones iniciales de la etapa (48,8 %) y mantiene capacitancia y fanout en cero. La reducción fue monotónica en los cuatro grupos. El área aumentó 351 unidades de área estándar respecto de `etapa17_group3`; el margen de hold siguió positivo, aunque disminuyó a +0,009199 ns.

## Evidencia post-route

Cada corrida generó SPEF mediante RCX en `asic/runs/etapa18_group{1,2,3,4}/12-openroad-rcx/{nom,min,max}`. Los reportes STA están en `13-openroad-stapostpnr/`, y las métricas consolidadas en `final/metrics.json`. Para `etapa18_group4` se verificó:

- Routing DRC: 0 errores (`05-checker-trdrc`).
- Magic DRC: limpio (`24-checker-magicdrc`).
- LVS: limpio (`29-checker-lvs`).
- Antena: 0 redes infractoras.
- XOR: diferencias despejadas (`21-checker-xor`).
- VDD/VSS: formas conectadas en el informe IR drop.
- Setup y hold: sin violaciones en los nueve corners.
- KLayout DRC: no ejecutado; `KLAYOUT_DRC_RUNSET` permanece sin definir y la métrica no está disponible.

Los GDS candidatos se encuentran en `asic/runs/etapa18_group{1,2,3,4}/final/gds/asic_top.gds`. Cada uno corresponde a su propio netlist, SPEF y layout. No se realizó una simulación funcional nueva porque no hubo cambios RTL; las pruebas RTL/post-síntesis previamente aprobadas siguen siendo aplicables a esta ECO física.

## Evaluación del cierre

No se alcanzó el cierre eléctrico completo: el mejor candidato, `etapa18_group4`, conserva **127 violaciones de slew**. Capacitancia y fanout permanecen en cero y el timing continúa positivo, pero faltan tanto slew=0 como la ejecución del deck externo de KLayout DRC. Por consiguiente, el GDSII de la etapa 18 es un candidato experimental, no un GDS de signoff.

El patrón de mejora confirma que el buffering dirigido es útil, pero las violaciones restantes están distribuidas entre múltiples conos combinacionales y salidas de registros. Continuar insertando buffers sin cambiar la estructura probablemente aumentaría área y podría consumir el margen de hold. La siguiente intervención justificada sería seleccionar drivers GF180 de mayor capacidad o reestructurar localmente los multiplexores/decodificación de ROM y register file, con equivalencia funcional explícita. Esa modificación estructural queda pendiente y no se implementó en esta etapa.

## Configuraciones y comandos

Configuraciones nuevas:

- `asic/rom_ram_stage18_group1.json`
- `asic/rom_ram_stage18_group2.json`
- `asic/rom_ram_stage18_group3.json`
- `asic/rom_ram_stage18_group4.json`

Diagnóstico reproducible:

```text
python scripts/stage16_diagnose.py --tag etapa18_group4
```

Los logs completos de LibreLane 3.0.16 están bajo `asic/runs/etapa18_group1` a `etapa18_group4`. Ninguna corrida anterior fue eliminada ni sobrescrita.

