#!/bin/sh
set -eu
[ -f audio.tar.gz ] || { echo "Missing audio.tar.gz" >&2; exit 1; }
# Extract the official flat archive without restoring ownership as root.
rm -rf stage
mkdir stage
tar --no-same-owner -xzf audio.tar.gz -C stage
for binary in audiocpp_server audiocpp_cli audiocpp_gguf; do
    [ -x "stage/$binary" ] || { echo "Missing executable: $binary" >&2; exit 1; }
done
rm -rf audio
mv stage audio
rm audio.tar.gz
# AMD's wheels are ZIP archives. Keep their sibling package layout and overlay
# per-GPU kernel files as pip would, without executing Python or an installer.
rm -rf rocm
mkdir rocm
for wheel in rocm-core.whl rocm-libraries.whl; do
    [ -f "$wheel" ] || { echo "Missing ROCm runtime wheel: $wheel" >&2; exit 1; }
    bsdtar --no-same-owner -xf "$wheel" -C rocm
    rm "$wheel"
done
# audio.cpp links HIP and BLAS. Preserve only their per-GPU kernel assets;
# FFT, convolution and other device code in the same wheels is not used.
for wheel in rocm-gfx*.whl; do
    [ -f "$wheel" ] || { echo "Missing ROCm device wheels" >&2; exit 1; }
    bsdtar --no-same-owner -xf "$wheel" -C rocm \
        --include '_rocm_sdk_libraries/.kpack/blas_lib_*' \
        --include '_rocm_sdk_libraries/lib/*blas*/*'
    rm "$wheel"
done
for library in _rocm_sdk_core/lib/libamdhip64.so.7 _rocm_sdk_libraries/lib/libhipblas.so.3 _rocm_sdk_libraries/lib/libhipblaslt.so.1; do
    [ -f "rocm/$library" ] || { echo "Missing ROCm runtime library: $library" >&2; exit 1; }
done
[ -d rocm/_rocm_sdk_libraries/.kpack ] || { echo "Missing ROCm kernel packs" >&2; exit 1; }
