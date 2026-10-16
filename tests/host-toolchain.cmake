# Builds the plugin and the unit tests with the build host's own compiler against a
# sysroot from tests/host-sysroot.sh, with a LuneOS build's native Qt tools
# (moc must match the target Qt):
#
#   cmake -S . -B build/tests-gcc -G Ninja -DBUILD_TESTING=ON \
#       -DCMAKE_TOOLCHAIN_FILE=tests/host-toolchain.cmake \
#       -DTEST_SYSROOT=<sysroot> -DQT_HOST_PATH=<qtbase-native etc.>/usr \
#       [-DTEST_TARGET=aarch64-webos-linux -DCMAKE_C_COMPILER=clang ...]
#
# TEST_TARGET is for the Clang compile checks of the other architectures.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSROOT ${TEST_SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${TEST_SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
set(QT_HOST_PATH_CMAKE_DIR ${QT_HOST_PATH}/lib/cmake)

if(TEST_TARGET)
    set(CMAKE_C_COMPILER_TARGET ${TEST_TARGET})
    set(CMAKE_CXX_COMPILER_TARGET ${TEST_TARGET})
endif()

# Not the build host's libraries at run time: tests run through the
# sysroot's loader (see tests/README.md).
set(CMAKE_SKIP_RPATH ON)

# Read again for every try_compile, where TEST_SYSROOT is only known if
# passed on; the environment below is the whole process's.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES TEST_SYSROOT TEST_TARGET)

# pkg-config (poppler-qt6) from the sysroot, not the build host.
if(TEST_SYSROOT)
    set(ENV{PKG_CONFIG_SYSROOT_DIR} ${TEST_SYSROOT})
    set(ENV{PKG_CONFIG_LIBDIR} ${TEST_SYSROOT}/usr/lib/pkgconfig:${TEST_SYSROOT}/usr/share/pkgconfig)
    set(ENV{PKG_CONFIG_PATH} "")
endif()
