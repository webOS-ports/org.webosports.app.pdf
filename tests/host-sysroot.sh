#!/bin/sh
# Puts together a sysroot for building the plugin and the unit tests, from a
# LuneOS build's sysroot components: Qt, poppler's dependencies, googletest
# and what they load. No recipe sysroot has poppler's Qt 6 library, so
# tests/build-poppler.sh adds it afterwards.
#
#   tests/host-sysroot.sh <TMPDIR of the build> <output dir> [arch [fallback arch]]
#
# arch is the sysroots-components directory, corei7-64 by default; aarch64
# or cortexa8t2hf-neon give the sysroots for the compile checks (not the
# -halium armv7 components: their GLES is libhybris, in each machine's own).
# A component that arch has only half staged (an empty directory - the
# armv7 qtdeclarative) is taken from the fallback arch, the same CPU:
#
#   tests/host-sysroot.sh <TMPDIR> <out> cortexa8t2hf-neon cortexa8t2hf-neon-halium
set -e
TMPDIR_BUILD=${1:?usage: host-sysroot.sh <build TMPDIR> <output dir> [arch [fallback arch]]}
OUT=${2:?usage: host-sysroot.sh <build TMPDIR> <output dir> [arch [fallback arch]]}
ARCH=${3:-corei7-64}
SC=$TMPDIR_BUILD/sysroots-components/$ARCH
FALLBACK=${4:+$TMPDIR_BUILD/sysroots-components/$4}

mkdir -p "$OUT"
for c in glibc gcc-runtime libgcc zlib zstd xz bzip2 openssl libffi glib-2.0 icu pcre2 \
         double-conversion libb2 brotli dbus systemd libcap util-linux-libuuid libxcrypt \
         qtbase qtdeclarative googletest \
         fontconfig freetype expat lcms libjpeg-turbo libpng openjpeg tiff libwebp libdeflate \
         libdrm libxkbcommon wayland harfbuzz graphite2 libglvnd mesa \
         linux-libc-headers libunwind libpthread-stubs util-linux pmloglib libpbnjson \
         llvm libxml2 ncurses elfutils libpciaccess libpcre2 yajl uriparser gmp; do
    if [ -d "$SC/$c/usr" ]; then
        cp -a "$SC/$c/." "$OUT/"
    elif [ -n "$FALLBACK" ] && [ -d "$FALLBACK/$c/usr" ]; then
        echo "$c: from $(basename "$FALLBACK")"
        cp -a "$FALLBACK/$c/." "$OUT/"
    fi
done
# The components drop their sysroot-providers stamps alongside; not needed.
rm -rf "$OUT/sysroot-providers"
echo "sysroot for $ARCH in $OUT"
