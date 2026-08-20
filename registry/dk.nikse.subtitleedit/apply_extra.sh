#!/bin/sh
set -eu

# Runs offline at install time inside org.gnome.Platform. Two kinds of payload
# arrive here: upstream's Subtitle Edit tarball, and FlatPark's prebuilt library
# stacks (https://github.com/flatpark/prebuilt), each pinned by sha256 in the
# manifest. Every stack unpacks to its own /app/extra/<name>/ directory, which is
# where the wrapper's LD_LIBRARY_PATH and PATH entries point.

extra_root="${EXTRA_ROOT:-/app/extra}"
cd "$extra_root"

# Each archive has a single top-level directory named after the stack, so a
# plain extract puts <name>/lib/... exactly where the wrapper expects it.
for stack in x264 x265 lame rubberband libass ffmpeg-full \
             leptonica tesseract uchardet sevenzip; do
    [ -f "$stack.tar.xz" ] || { echo "missing extra-data: $stack.tar.xz" >&2; exit 1; }
    rm -rf "$stack"
    tar --no-same-owner -xJf "$stack.tar.xz" -C .
    [ -d "$stack" ] || { echo "$stack.tar.xz did not yield a $stack/ directory" >&2; exit 1; }
    rm -f "$stack.tar.xz"
done

[ -x ffmpeg-full/bin/ffmpeg ] || { echo "ffmpeg missing after unpack" >&2; exit 1; }
[ -x tesseract/bin/tesseract ] || { echo "tesseract missing after unpack" >&2; exit 1; }
[ -x sevenzip/bin/7zr ] || { echo "7zr missing after unpack" >&2; exit 1; }

# tesseract resolves both its output-format presets and its language data from
# TESSDATA_PREFIX, and the stack already ships share/tessdata/configs. Put the
# language file beside them rather than pointing at a second directory.
[ -f eng.traineddata ] || { echo "missing extra-data: eng.traineddata" >&2; exit 1; }
mv eng.traineddata tesseract/share/tessdata/eng.traineddata

[ -f subtitleedit.tar.gz ] || { echo "missing extra-data: subtitleedit.tar.gz" >&2; exit 1; }
rm -rf stage app
mkdir stage
tar --no-same-owner -xf subtitleedit.tar.gz -C stage
[ -x stage/SubtitleEdit ] || { echo "SubtitleEdit binary not found in tarball" >&2; exit 1; }
mv stage app
rm -f subtitleedit.tar.gz
