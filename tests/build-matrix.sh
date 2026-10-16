#!/bin/sh
# Builds the plugin (and on x86-64 the unit tests) six ways - GCC and Clang
# for armv7, aarch64 and x86-64 - with extra warnings, and fails on any
# warning in the app's own code.
#
#   tests/build-matrix.sh <build TMPDIR> <sysroots dir> <Qt host dir> <out dir>
#
# The sysroots dir holds sysroot-x86_64, sysroot-aarch64 and sysroot-armv7
# from tests/host-sysroot.sh and tests/build-poppler.sh (no recipe sysroot
# has poppler's Qt 6 library). GCC for armv7 and aarch64 is the cross GCC of
# a recipe that built for them (the Camera app's); Clang is the build host's,
# pointed at the same sysroots. The Qt host dir is qtbase-native etc.
set -e
cd "$(dirname "$0")/.."
TMPD=${1:?usage: build-matrix.sh <build TMPDIR> <sysroots dir> <Qt host dir> <out dir>}
SYSROOTS=${2:?}
QTHOST=${3:?}
OUT=${4:?}
SRC=$(pwd)
WARN="-Wall -Wextra -Wpedantic -Wshadow -Wnon-virtual-dtor -Wold-style-cast -Wcast-align -Wformat=2"
mkdir -p "$OUT"
FAILED=$OUT/failed
rm -f "$FAILED"

camera_dir() {
    ls -d "$TMPD"/work/"$1"/org.webosports.app.camera/*/ | head -n 1
}

build() {   # name cmake-args...
    name=$1; shift
    dir=$OUT/$name
    rm -rf "$dir"
    if ! cmake -S "$SRC" -B "$dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_TOOLCHAIN_FILE="$SRC/tests/host-toolchain.cmake" -DQT_HOST_PATH="$QTHOST" "$@" \
            > "$dir.cmake.log" 2>&1; then
        echo "$name: configure FAILED (see $dir.cmake.log)"; touch "$FAILED"; return
    fi
    if ! ninja -C "$dir" > "$dir.log" 2>&1; then
        echo "$name: build FAILED (see $dir.log)"; touch "$FAILED"; return
    fi
    # Warnings from the app's own files; Qt's and poppler's headers apart.
    own=$(grep -E "warning:" "$dir.log" | grep -E "$SRC/(PdfViewerApp|tests)/" | sort -u | wc -l)
    other=$(grep -E "warning:" "$dir.log" | grep -v -E "$SRC/(PdfViewerApp|tests)/" | sort -u | wc -l)
    echo "$name: built, $own warnings in our code, $other elsewhere"
    [ "$own" -eq 0 ] || touch "$FAILED"
}

# Clang has no idea of Yocto's layout: the GCC runtime (crtbeginS.o,
# libgcc) is in usr/lib/<triple>/<version>, libstdc++'s headers in
# usr/include/c++/<version>.
clang_flags() {   # sysroot triple
    gcclib=$(dirname "$(find "$1/usr/lib" -name crtbeginS.o | head -n 1)")
    ver=$(basename "$gcclib")
    echo "-B$gcclib -isystem $1/usr/include/c++/$ver -isystem $1/usr/include/c++/$ver/$2"
}

clang_ldflags() {   # sysroot [linker]
    gcclib=$(dirname "$(find "$1/usr/lib" -name crtbeginS.o | head -n 1)")
    echo "-L$gcclib${2:+ --ld-path=$2}"
}

for arch in armv7 aarch64; do
  (
    if [ $arch = armv7 ]; then
        D=$(camera_dir cortexa8t2hf-neon-halium-webos-linux-gnueabi); triple=arm-webos-linux-gnueabi
        cpu="-mthumb -mfpu=neon -mfloat-abi=hard -mcpu=cortex-a8"
    else
        D=$(camera_dir aarch64-webos-linux); triple=aarch64-webos-linux; cpu=""
    fi
    SR=$SYSROOTS/sysroot-$arch
    NATIVE=$D/recipe-sysroot-native/usr
    GCC=$NATIVE/bin/$triple/$triple-gcc
    build "$arch-gcc" -DTEST_SYSROOT="$SR" -DCMAKE_C_COMPILER="$GCC" -DCMAKE_CXX_COMPILER="${GCC%gcc}g++" \
        -DCMAKE_CXX_FLAGS="$cpu $WARN" -DCMAKE_C_FLAGS="$cpu"
    flags=$(clang_flags "$SR" "$triple")
    ld=$(clang_ldflags "$SR" "$NATIVE/bin/$triple/$triple-ld")
    build "$arch-clang" -DTEST_SYSROOT="$SR" -DTEST_TARGET="$triple" \
        -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
        -DCMAKE_CXX_FLAGS="$cpu $flags $WARN" -DCMAKE_C_FLAGS="$cpu $flags" \
        -DCMAKE_SHARED_LINKER_FLAGS="$ld" -DCMAKE_MODULE_LINKER_FLAGS="$ld" -DCMAKE_EXE_LINKER_FLAGS="$ld"
  )
done

X86=$SYSROOTS/sysroot-x86_64
for cc in gcc clang; do
    cxx=$([ $cc = gcc ] && echo g++ || echo clang++)
    extra=""
    ld=""
    if [ $cc = clang ]; then extra=$(clang_flags "$X86" x86_64-webos-linux); ld=$(clang_ldflags "$X86"); fi
    build "x86_64-$cc" -DBUILD_TESTING=ON -DTEST_SYSROOT="$X86" \
        -DCMAKE_C_COMPILER=$cc -DCMAKE_CXX_COMPILER=$cxx -DCMAKE_CXX_FLAGS="$extra $WARN" -DCMAKE_C_FLAGS="$extra" \
        -DCMAKE_SHARED_LINKER_FLAGS="$ld" -DCMAKE_MODULE_LINKER_FLAGS="$ld" -DCMAKE_EXE_LINKER_FLAGS="$ld"
done

[ ! -e "$FAILED" ]
