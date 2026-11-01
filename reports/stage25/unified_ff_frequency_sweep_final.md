# Etapa 25 — barrido temporal de memoria unificada

## Alcance y método

Se caracterizó la arquitectura de memoria unificada con flip-flops (MemoryArchitecture=2), manteniendo FP_CORE_UTIL=40, PDK GF180MCU, LibreLane 3.0.16 y Docker Engine 29.7.2. Las corridas se ejecutaron con etiquetas independientes y se conservaron los resultados previos.

El criterio temporal se evaluó mediante STA post-route en los nueve corners. Un período se clasifica como cumplido cuando setup y hold tienen WNS no negativo y TNS igual a cero en todos los corners. El barrido no es una búsqueda continua de todos los períodos posibles.

## Resultados consolidados

| Período | Frecuencia | Setup WNS / TNS | Hold WNS / TNS | Estado |
|---:|---:|---:|---:|---|
| 100 ns | 10,000 MHz | +23,747405 / 0 | +0,171725 / 0 | Cumple (corrida histórica) |
| 80 ns | 12,500 MHz | +16,789962 / 0 | +0,139166 / 0 | Cumple |
| 70 ns | 14,286 MHz | +6,789961 / 0 | +0,139166 / 0 | Cumple |
| 65 ns | 15,385 MHz | +1,789957 / 0 | +0,139166 / 0 | Cumple |
| **64 ns** | **15,625 MHz** | **+0,789960 / 0** | **+0,139166 / 0** | **Menor período demostrado que cumple** |
| 63 ns | 15,873 MHz | −0,210036 / −0,821011 | 0 / 0 | Falla setup |
| 62 ns | 16,129 MHz | −1,210040 / −13,861495 | +0,139166 / 0 | Falla setup |
| 60 ns | 16,667 MHz | −3,210040 / −184,688650 | +0,139166 / 0 | Falla setup |

El peor corner de la corrida de 63 ns es max_ss_125C_4v50. La corrida etapa25_unified_ff_63ns_retry llegó a STA post-route en los nueve corners, pero el flujo se detuvo en ese paso; por ello no generó un GDS propio. Esto no invalida el resultado STA.

## Métricas físicas y limitaciones

En las corridas nuevas de 80–60 ns se reportaron área stdcell de 724673 µm², área de die de 1468100 µm² y utilización real de 51,3187 %. El peor conteo eléctrico reportado fue 10758 violaciones de slew, 730 de capacitancia y 355 de fanout. Por tanto, el cumplimiento de setup/hold de la memoria unificada no equivale a cierre eléctrico completo.

La corrida histórica de 100 ns tiene datos propios: área stdcell 730205 µm², utilización 51,6617 % y 9734/949/350 violaciones de slew/capacitancia/fanout. No se deben mezclar estas métricas con las corridas nuevas.

## Conclusión

La menor frecuencia/período demostrado en este barrido que cumple setup y hold para memoria unificada es **15,625 MHz (64 ns)**. El período inmediatamente probado de 63 ns falla setup; 62 y 60 ns también fallan. El límite queda acotado entre 63 y 64 ns para las configuraciones ensayadas; no se afirma una frecuencia máxima matemática ni se interpolan resultados.

La comparación con ROM+RAM debe distinguir que su corrida de cierre eléctrico es etapa21_combined a 100 ns, mientras que el menor período ROM+RAM que cumplió timing en el barrido histórico fue 62 ns. Las métricas físicas y eléctricas de una arquitectura no se transfieren a la otra.