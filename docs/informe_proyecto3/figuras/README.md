# Figuras incluidas en el paquete Overleaf

Todas las dependencias gráficas están dentro de esta carpeta y son compatibles con pdfLaTeX:

- `pochoco_soc.pdf`: conversión directa del SVG existente del SoC.
- `etapa5_utilizacion.pdf`: conversión directa del gráfico SVG de Etapa 5.
- `etapa5_pinout_util50.pdf`: conversión directa del SVG de terminales de Etapa 5.
- `etapa6_layout_trazabilidad.pdf`: conversión directa del SVG de trazabilidad de Etapa 6.
- `etapa9_render.png`: render original de la corrida reglamentaria de Etapa 9.

Las conversiones se realizaron sin editar los SVG fuente. `main.tex` usa `\includegraphics`; no requiere Inkscape ni `--shell-escape`.
