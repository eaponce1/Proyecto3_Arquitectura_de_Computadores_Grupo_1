# Compilación del informe final

El documento principal es `main.tex`, la bibliografía es `referencias.bib` y el fragmento de citas integrado es `citas_oficiales.tex`. Todas las figuras requeridas están en `figuras/`.

## Compilación local

Se requiere una distribución LaTeX con `pdflatex` y `bibtex`. Todas las figuras ya están en PDF o PNG, por lo que no se requiere Inkscape ni `--shell-escape`. Desde esta carpeta:

```sh
latexmk -pdf main.tex
cp main.pdf ../informe_proyecto3.pdf
```

En PowerShell, el segundo comando equivalente es:

```powershell
Copy-Item .\main.pdf ..\informe_proyecto3.pdf
```

Las figuras del paquete ya fueron convertidas desde los SVG originales sin modificar su contenido.

## Overleaf

Subir el contenido de esta carpeta, seleccionar `main.tex` como documento principal y compilar con pdfLaTeX. No se requiere shell escape. La salida esperada se puede renombrar a `Proyecto3_Overleaf.pdf` al descargarla.

## Revisión manual pendiente

- Inspeccionar visualmente las tablas anchas y las figuras después de compilar.
- Mantener explícito que las Etapas 9, 12 y 13 presentan violaciones eléctricas, mientras que `etapa21_combined` alcanza 0/0/0 (slew/capacitancia/fanout) y timing positivo en nueve corners. La implementación representa cierre del macro bajo las restricciones disponibles, no certificación de un chip completo con pads e I/O.
- Las simulaciones completas de ronda correcta, incorrecta y diez rondas de Etapa 7 no deben confundirse con la validación parcial de 208 y 1008 ciclos de la Etapa 21.
- El PDF publicado debe recompilarse después de cambiar `main.tex`; hasta entonces, el PDF anterior no contiene todas las correcciones de presentación.
