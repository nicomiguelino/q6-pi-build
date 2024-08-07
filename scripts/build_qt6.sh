#!/bin/bash

set -euo pipefail


# Enable script debugging if the DEBUG environment variable is set and non-zero.
if [ "${DEBUG:-0}" -ne 0 ]; then
    set -x
fi

function download_toolchain() {
    mkdir -p cross-tools && cd cross-tools

    BINUTILS_PATH=binutils-2.40.tar.gz
    GLIBC_PATH=glibc-2.36.tar.gz
    GCC_PATH=gcc-12.2.0.tar.gz

    if [ ! -f "$BINUTILS_PATH" ]; then
        wget https://mirror.lyrahosting.com/gnu/binutils/$BINUTILS_PATH
        tar xf $BINUTILS_PATH
    fi

    if [ ! -f "$GLIBC_PATH" ]; then
        wget https://ftp.nluug.nl/pub/gnu/glibc/$GLIBC_PATH
        tar xf $GLIBC_PATH
    fi

    if [ ! -f "$GCC_PATH" ]; then
        wget https://ftp.nluug.nl/pub/gnu/gcc/gcc-12.2.0/$GCC_PATH
        tar xf $GCC_PATH
    fi

    if [ ! -d "./linux" ]; then
        git clone --depth=1 https://github.com/raspberrypi/linux
    fi
}

function compile_toolchain() {
    export PATH=/opt/cross-pi-gcc/bin:$PATH
    mkdir -p /opt/cross-pi-gcc

    cd /build/cross-tools/linux/
    KERNEL=kernel8
    make ARCH=arm64 INSTALL_HDR_PATH=/opt/cross-pi-gcc/aarch64-linux-gnu headers_install

    if [ -d "/opt/cross-pi-gcc/bin" ] && [ "$(ls -A /opt/cross-pi-gcc/bin)" ]; then
        echo "Toolchain already exists."
        return
    fi

    cd ../
    mkdir -p build-binutils && cd build-binutils
    ../binutils-2.40/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --with-arch=armv8 --disable-multilib
    make -j10
    make install
    echo "Binutils done"

    cd ../
    sed -i '66a #ifndef PATH_MAX\n#define PATH_MAX 4096\n#endif' /build/cross-tools/gcc-12.2.0/libsanitizer/asan/asan_linux.cpp

    mkdir -p build-gcc && cd build-gcc
    ../gcc-12.2.0/configure --prefix=/opt/cross-pi-gcc --target=aarch64-linux-gnu --enable-languages=c,c++ --disable-multilib
    make -j10 all-gcc
    make install-gcc
    echo "Compile glibc partly"

    cd ../
    mkdir -p build-glibc && cd build-glibc
    ../glibc-2.36/configure \
        --prefix=/opt/cross-pi-gcc/aarch64-linux-gnu \
        --build=$MACHTYPE \
        --host=aarch64-linux-gnu \
        --target=aarch64-linux-gnu \
        --with-headers=/opt/cross-pi-gcc/aarch64-linux-gnu/include \
        --disable-multilib \
        libc_cv_forced_unwind=yes
    make install-bootstrap-headers=yes install-headers
    make -j10 csu/subdir_lib
    install csu/crt1.o csu/crti.o csu/crtn.o /opt/cross-pi-gcc/aarch64-linux-gnu/lib
    aarch64-linux-gnu-gcc -nostdlib -nostartfiles -shared -x c /dev/null -o /opt/cross-pi-gcc/aarch64-linux-gnu/lib/libc.so
    touch /opt/cross-pi-gcc/aarch64-linux-gnu/include/gnu/stubs.h
    echo "Build gcc partly"

    cd ../build-gcc/
    make -j10 all-target-libgcc
    make install-target-libgcc
    echo "build complete glibc"

    cd ../build-glibc/
    make -j10
    make install
    echo "build complete gcc"

    cd ../build-gcc/
    make -j10
    make install
    echo "Is finished"
}

function setup_sysroot() {
    cd /build
    mkdir -p sysroot sysroot/usr sysroot/opt
    cp /tmp/rasp.tar.gz .
    tar xfz /build/rasp.tar.gz -C /build/sysroot

    if [ ! -d "./firmware" ]; then
        git clone --depth=1 https://github.com/raspberrypi/firmware firmware
    fi

    if [ -d "./firmware/opt" ]; then
        cp -r ./firmware/opt sysroot
    else
        echo "./firmware/opt does not exist. Skipping..."
    fi
}

function main() {
    download_toolchain
    compile_toolchain
    setup_sysroot

    # TODO: Create a `toolchain.cmake` file.
}

main
