#!/bin/bash

set -euo pipefail


function install_cross_build_tools() {
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

    git clone --depth=1 https://github.com/raspberrypi/linux
}

function main() {
    install_cross_build_tools
    mkdir -p /opt/cross-pi-gcc
    export PATH=/opt/cross-pi-gcc/bin:$PATH
}

main
