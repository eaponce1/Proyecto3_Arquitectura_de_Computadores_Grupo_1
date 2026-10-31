"""Build the self-contained Overleaf ZIP from the report's local dependencies."""

from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "docs" / "informe_proyecto3"
OUTPUT = ROOT / "docs" / "Proyecto3_Overleaf.zip"


def main() -> None:
    main_tex = REPORT / "main.tex"
    source = main_tex.read_text(encoding="utf-8")

    files = {"main.tex"}
    files.update(re.findall(r"\\includegraphics(?:\[[^]]*\])?\{([^}]+)\}", source))
    files.update(re.findall(r"\\input\{([^}]+)\}", source))
    files.update(f"{name}.bib" for name in re.findall(r"\\bibliography\{([^}]+)\}", source))

    for relative in files:
        path = Path(relative)
        if path.is_absolute() or ".." in path.parts:
            raise ValueError(f"External dependency is not allowed: {relative}")
        if not (REPORT / path).is_file():
            raise FileNotFoundError(f"Missing report dependency: {relative}")
        if path.suffix.lower() == ".svg":
            raise ValueError(f"SVG cannot be included directly with pdfLaTeX: {relative}")

    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for relative in sorted(files):
            archive.write(REPORT / relative, arcname=relative)

    with zipfile.ZipFile(OUTPUT) as archive:
        if "main.tex" not in archive.namelist() or archive.testzip() is not None:
            raise RuntimeError("Overleaf ZIP integrity check failed")
        print(f"{OUTPUT}: {len(archive.namelist())} files, {OUTPUT.stat().st_size} bytes")


if __name__ == "__main__":
    main()
