#!/bin/sh
# Builds poppler's Qt 6 library into a sysroot from tests/host-sysroot.sh,
# from the same release the image builds (the tarball in the build's
# downloads). The image's poppler recipe has its qt6 PACKAGECONFIG off, so no
# recipe sysroot has it.
#
#   tests/build-poppler.sh <build TMPDIR> <sysroot> <x86_64|aarch64|armv7> <Qt host dir> <work dir>
#
# x86_64 builds with the build host's GCC; aarch64 and armv7 with the cross
# GCC of a recipe that already built for them (the Camera app's).
set -e
TMPD=${1:?usage: build-poppler.sh <build TMPDIR> <sysroot> <arch> <Qt host dir> <work dir>}
SYSROOT=${2:?}
ARCH=${3:?}
QTHOST=${4:?}
WORK=${5:?}
HERE=$(cd "$(dirname "$0")" && pwd)
VER=25.12.0

camera_dir() {
    ls -d "$TMPD"/work/"$1"/org.webosports.app.camera/*/ | head -n 1
}

mkdir -p "$WORK"
[ -d "$WORK/poppler-$VER" ] || tar -C "$WORK" -xf "$TMPD/../downloads/poppler-$VER.tar.xz"

case $ARCH in
    x86_64)
        CC=gcc; CXX=g++; CPU="" ;;
    aarch64)
        D=$(camera_dir aarch64-webos-linux)
        CC=$D/recipe-sysroot-native/usr/bin/aarch64-webos-linux/aarch64-webos-linux-gcc
        CXX=${CC%gcc}g++; CPU="" ;;
    armv7)
        D=$(camera_dir cortexa8t2hf-neon-halium-webos-linux-gnueabi)
        CC=$D/recipe-sysroot-native/usr/bin/arm-webos-linux-gnueabi/arm-webos-linux-gnueabi-gcc
        CXX=${CC%gcc}g++; CPU="-mthumb -mfpu=neon -mfloat-abi=hard -mcpu=cortex-a8" ;;
    *)
        echo "unknown arch $ARCH"; exit 1 ;;
esac

B=$WORK/build-$ARCH
rm -rf "$B"
# Only what the viewer needs: the core and the Qt 6 frontend, with the
# image's decoders (JPEG, JPEG 2000, PNG, TIFF) and colour management.
cmake -S "$WORK/poppler-$VER" -B "$B" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$HERE/host-toolchain.cmake" -DTEST_SYSROOT="$SYSROOT" \
    -DQT_HOST_PATH="$QTHOST" -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_C_FLAGS="$CPU" -DCMAKE_CXX_FLAGS="$CPU" \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
    -DENABLE_QT6=ON -DENABLE_QT5=OFF -DENABLE_GLIB=OFF -DENABLE_CPP=OFF -DENABLE_UTILS=OFF \
    -DENABLE_BOOST=OFF -DENABLE_NSS3=OFF -DENABLE_GPGME=OFF -DENABLE_LIBCURL=OFF \
    -DENABLE_LCMS=ON -DENABLE_LIBOPENJPEG=openjpeg2 -DENABLE_DCTDECODER=libjpeg \
    -DENABLE_GOBJECT_INTROSPECTION=OFF -DBUILD_GTK_TESTS=OFF -DBUILD_QT6_TESTS=OFF \
    -DBUILD_CPP_TESTS=OFF -DBUILD_MANUAL_TESTS=OFF -DRUN_GPERF_IF_PRESENT=OFF \
    -DENABLE_UNSTABLE_API_ABI_HEADERS=OFF
ninja -C "$B"
DESTDIR="$SYSROOT" ninja -C "$B" install
echo "poppler-qt6 $VER for $ARCH in $SYSROOT"
