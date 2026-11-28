#!/bin/sh
set -eu
cd "${EXTRA_ROOT:-/app/extra}"
[ -f llama.tar.gz ] || { echo 'missing extra-data: llama.tar.gz' >&2; exit 1; }
rm -rf stage llama rocm
mkdir stage
# System installs run as root without ownership-restoration capabilities.
bsdtar --no-same-owner -xf llama.tar.gz -C stage
top="$(find stage -mindepth 1 -maxdepth 1 -type d)"
[ "$(printf '%s\n' "$top" | wc -l)" -eq 1 ] && [ -n "$top" ] || {
    echo 'expected one upstream llama directory' >&2; exit 1;
}
mv "$top" llama
for binary in llama llama-server llama-cli llama-bench llama-quantize; do
    [ -x "llama/$binary" ] || { echo "missing upstream executable: $binary" >&2; exit 1; }
done
# Keep AMD's wheel trees side by side: their RUNPATHs cross between them.
# Per-GPU wheels overlay the libraries tree with unchanged kernel files.
mkdir rocm
for wheel in rocm-core.whl rocm-libraries.whl \
    rocm-gfx908.whl rocm-gfx90a.whl rocm-gfx942.whl rocm-gfx950.whl \
    rocm-gfx1010.whl rocm-gfx1011.whl rocm-gfx1012.whl \
    rocm-gfx1030.whl rocm-gfx1031.whl rocm-gfx1032.whl rocm-gfx1033.whl \
    rocm-gfx1034.whl rocm-gfx1035.whl rocm-gfx1036.whl \
    rocm-gfx1100.whl rocm-gfx1101.whl rocm-gfx1102.whl rocm-gfx1103.whl \
    rocm-gfx1150.whl rocm-gfx1151.whl rocm-gfx1152.whl \
    rocm-gfx1200.whl rocm-gfx1201.whl; do
    [ -f "$wheel" ] || { echo "missing extra-data: $wheel" >&2; exit 1; }
    bsdtar --no-same-owner -xf "$wheel" -C rocm
    case "$wheel" in
        rocm-gfx*.whl)
            target="${wheel#rocm-}"
            target="${target%.whl}"
            [ -f "rocm/_rocm_sdk_libraries/.kpack/blas_lib_$target.kpack" ] || {
                echo "missing AMD BLAS kernels: $target" >&2; exit 1;
            }
            ;;
    esac
    rm "$wheel"
done
for library in _rocm_sdk_core/lib/libamdhip64.so.7 \
    _rocm_sdk_libraries/lib/libhipblas.so.3 \
    _rocm_sdk_libraries/lib/librocblas.so.5; do
    [ -f "rocm/$library" ] || { echo "missing AMD library: $library" >&2; exit 1; }
done
rm -rf stage llama.tar.gz
