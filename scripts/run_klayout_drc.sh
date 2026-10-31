#!/bin/sh
set -eu

# Run the unmodified GF180MCU KLayout DRC driver distributed by open_pdks.
# Execute from WSL; both argument paths must remain inside this repository.
image=${LIBRELANE_IMAGE:-ghcr.io/librelane/librelane:3.0.16}
pdk_root=${PDK_ROOT:-"$HOME/.ciel"}
repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
gds=${1:-asic/runs/etapa9_rom_ram_util40_debounce/final/gds/asic_top.gds}
run_dir=${2:-reports/stage9/klayout_drc_repro}

case "$gds" in
    /*) gds_abs=$gds ;;
    *)  gds_abs=$repo_root/$gds ;;
esac
case "$run_dir" in
    /*) run_abs=$run_dir ;;
    *)  run_abs=$repo_root/$run_dir ;;
esac

case "$gds_abs" in
    "$repo_root"/*) gds_container=/work/${gds_abs#"$repo_root"/} ;;
    *) echo "error: el GDS debe estar dentro del repositorio: $repo_root" >&2; exit 2 ;;
esac
case "$run_abs" in
    "$repo_root"/*) run_container=/work/${run_abs#"$repo_root"/} ;;
    *) echo "error: el directorio de resultados debe estar dentro del repositorio" >&2; exit 2 ;;
esac

test -f "$gds_abs" || { echo "error: no existe $gds_abs" >&2; exit 2; }
test -f "$pdk_root/gf180mcuD/libs.tech/klayout/drc/run_drc.py" || {
    echo "error: no se encontro el deck bajo $pdk_root/gf180mcuD" >&2
    exit 2
}
test -f "$repo_root/reports/stage9/python_deps/docopt.py" || {
    echo "error: falta docopt; ejecute: python3 -m pip install --target reports/stage9/python_deps docopt==0.6.2" >&2
    exit 2
}
test -f "$repo_root/reports/stage9/bin/pmap" || {
    echo "error: falta reports/stage9/bin/pmap" >&2
    exit 2
}

mkdir -p "$run_abs"
container_path=$(docker run --rm "$image" sh -c 'printf %s "$PATH"')

docker run --rm \
    -e "PATH=/work/reports/stage9/bin:$container_path" \
    -e PYTHONPATH=/work/reports/stage9/python_deps \
    -v "$pdk_root/gf180mcuD:/pdk:ro" \
    -v "$repo_root:/work" -w /work \
    "$image" \
    python3 /pdk/libs.tech/klayout/drc/run_drc.py \
    --path="$gds_container" --variant=D --topcell=asic_top \
    --run_dir="$run_container" --run_mode=deep --mp=4
