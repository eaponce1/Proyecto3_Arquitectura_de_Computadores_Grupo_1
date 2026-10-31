# Evidencias Etapa 12

Corridas nuevas: etapa12_rom_ram_no_dlyb, etapa12_rom_ram_no_delay y
etapa12_rom_ram_no_delay_ss. Baseline intacta: etapa9_rom_ram_util40_debounce.

- comparison.csv / comparison.json: valores oficiales de final/metrics.json.
- timing_nine_corners.csv: WNS/TNS/WS y conteos por corner.
- signoff_no_delay_ss.json: mejor candidato; **sin cierre eléctrico**.
- Cada carpeta <tag>: corners.csv, summary.json, nets.json y violations.json.
  Los drivers/cargas se obtienen usando cell_pin_directions.json, extraído
  de la Liberty GF180MCU real. Incluye procedencia y hash.
- Los archivos classified.json / classified.csv de la carpeta SS son una
  salida auxiliar preliminar del analizador anterior. Su lista global de
  pines de salida clasifica incorrectamente S de mux2_2. **No usar estos
  dos archivos para atribución de drivers ni módulos**. Los conteos originales
  STA siguen siendo correctos; usar nets.json/summary.json corregidos.
- worst_*.rpt e independent_worst.json son lecturas independientes auxiliares.
  No sustituyen los slacks oficiales, que están en final/metrics.json.
- klayout_no_delay_ss/: deck externo sin cambios y reportes originales.
- Los .log de launcher y sus manifiestos preservan comandos/hashes.

Los sondeos all_electrical_max_ss, v2 y v3 contienen errores de preparación
de una lectura auxiliar; v4 es el sondeo válido de la baseline. No son
experimentos físicos adicionales. La distribución dirigida de reloj solo
se inventarió; el paso de inserción preparado **no se ejecutó**.

La documentación consolidada está en docs/proyecto3_etapa12.md.

