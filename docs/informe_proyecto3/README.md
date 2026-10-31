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
- Mantener explícito que el GDSII es candidato: persisten 2695/10/58 violaciones de slew/capacitancia/fanout en la baseline reglamentaria de Etapa 9 y 440/2/57 en la mejor candidata técnica de Etapa 12. Las variantes de Etapa 13 tampoco cierran el diseño.
