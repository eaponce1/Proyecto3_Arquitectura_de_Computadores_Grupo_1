# Proyecto 3 — Revisión de referencias oficiales

Fecha de revisión: 24 de octubre de 2026.

## Fuentes revisadas

1. LibreLane, [documentación estable](https://librelane.readthedocs.io/en/stable/).
2. GlobalFoundries, [documentación GF180MCU PDK](https://gf180mcu-pdk.readthedocs.io/en/latest/).
3. OpenROAD, [documentación oficial](https://openroad.readthedocs.io/en/latest/).

## Coherencia comprobada

| Tema | Evidencia del proyecto | Contraste con documentación oficial | Estado |
|---|---|---|---|
| Configuración del flujo | JSON resuelto de `etapa9_rom_ram_util40_debounce`: `DESIGN_NAME=asic_top`, `CLOCK_PORT=clk_i`, `CLOCK_PERIOD=100`, `FP_CORE_UTIL=40` | LibreLane admite archivos JSON y documenta esos campos como parámetros normales de una configuración de diseño | Coherente |
| Trazabilidad | `resolved.json`, `flow.log`, estados y métricas por etapa | LibreLane describe el flujo como reproducible y conserva configuración/estado por paso | Coherente |
| Tecnología y biblioteca | `PDK=gf180mcuD`; `STD_CELL_LIBRARY=gf180mcu_fd_sc_mcu7t5v0`; revisión `8afc8346a57fe1ab7934ba5a6056ea8b43078e71` | La documentación GF180MCU cubre la familia 0.18 µm y enumera la biblioteca estándar `gf180mcu_fd_sc_mcu7t5v0` de siete tracks | Coherente; `gf180mcuD` es la variante instalada por Open_PDKs, no un cambio de tecnología |
| Floorplan y utilización | Corridas de 30 %, 40 % y 50 %; áreas de core y die conservadas | OpenROAD documenta que puede derivar el core desde área de diseño, utilización y aspecto, o recibir áreas explícitas | Coherente |
| Placement, CTS y routing | Logs de global placement, CTS, global routing y detailed routing de cada corrida | OpenROAD documenta estas etapas, así como extracción RC post-route y los routers empleados | Coherente |
| STA multicorner | `55-openroad-stapostpnr/<corner>/` y métricas de nueve combinaciones interconnect/PVT | LibreLane documenta que los corners combinan información PVT e interconexión | Coherente |

## Limitaciones y discrepancias que deben quedar explícitas

No se encontró una discrepancia que exija cambiar RTL, las configuraciones o
las corridas existentes. Sí existen los siguientes límites para el informe:

1. La revisión se hizo contra la documentación `stable`/`latest` publicada el
   24 de octubre de 2026, mientras las corridas son reproducibles con
   LibreLane **3.0.16**. La documentación respalda el procedimiento general,
   no debe presentarse como garantía de que cada opción tenga idéntico nombre
   o comportamiento en versiones posteriores.
2. En la corrida reglamentaria, `PNR_SDC_FILE` y `SIGNOFF_SDC_FILE` no están
   definidos; LibreLane usó su SDC genérica. Por tanto, setup/hold en nueve
   corners son resultados reales bajo esas restricciones, pero no sustituyen
   una caracterización de I/O con delays, transiciones y cargas de un chip con
   pads/package reales.
3. La documentación pública de GF180MCU se identifica como *Experimental
   Preview*. Esto refuerza que los resultados del proyecto son académicos y
   que DRC/LVS/antena limpios no equivalen por sí solos a una aprobación de
   fabricación.
4. La corrida reglamentaria sigue teniendo violaciones eléctricas. Ninguna
   cita oficial debe utilizarse para presentar el GDSII candidato como GDSII
   definitivo.

## Integración LaTeX

El repositorio no contiene un informe principal `.tex` ni una bibliografía
previa. Para que la integración no invente ni reemplace dicho informe, se
entregan dos artefactos reutilizables:

- `docs/proyecto3_referencias_oficiales.bib`: bibliografía BibTeX de las tres fuentes.
- `docs/proyecto3_citas_oficiales.tex`: texto con las tres citas, preparado
  para incluirse en las secciones de flujo RTL--GDSII, tecnología/PDK y
  implementación física/STA del informe.

El archivo principal deberá incluir el fragmento y una de las dos alternativas
de bibliografía indicadas en sus comentarios.
