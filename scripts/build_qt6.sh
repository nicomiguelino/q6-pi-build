#!/bin/bash

set -euo pipefail


# Enable script debugging if the DEBUG environment variable is set and non-zero.
if [ "${DEBUG:-0}" -ne 0 ]; then
    set -x
fi

CORE_COUNT="$(expr $(nproc) - 2)"
QT_MAJOR='6'
QT_MINOR='6'
QT_PATCH='3'
QT_VERSION="${QT_MAJOR}.${QT_MINOR}.${QT_PATCH}"
QT6_PI_STAGING_PATH="/usr/local/qt6"
DEBIAN_VERSION='bookworm'

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

function copy_toolchain_cmake() {
    cp /src/toolchain.cmake /build
}

function fix_symbolic_links() {
    SYSROOT_RELATIVE_LINKS_SCRIPT="sysroot-relativelinks.py"
    SYSROOT_RELATIVE_LINKS_DOWNLOAD_URL="https://raw.githubusercontent.com/riscv/riscv-poky/master/scripts/${SYSROOT_RELATIVE_LINKS_SCRIPT}"

    echo "Fix symbollic links"

    if [ ! -f "${SYSROOT_RELATIVE_LINKS_SCRIPT}" ]; then
        echo "Downloading ${SYSROOT_RELATIVE_LINKS_SCRIPT}..."
        wget "${SYSROOT_RELATIVE_LINKS_DOWNLOAD_URL}"
    else
        echo "Script ${SYSROOT_RELATIVE_LINKS_SCRIPT} already exists. Skipping download..."
    fi

    chmod +x sysroot-relativelinks.py
    python3 sysroot-relativelinks.py /build/sysroot
}

function install_qt() {
    QT_DOWNLOAD_BASE_URL="https://download.qt.io/official_releases/qt/${QT_MAJOR}.${QT_MINOR}/${QT_VERSION}/submodules"
    QT_ARCHIVE_FILES=(
        "qtbase-everywhere-src-${QT_VERSION}.tar.xz"
        "qtshadertools-everywhere-src-${QT_VERSION}.tar.xz"
        "qtdeclarative-everywhere-src-${QT_VERSION}.tar.xz"
        "qtwebengine-everywhere-src-${QT_VERSION}.tar.xz"
    )
    QT6_DIR="/build/qt6"
    QT6_SRC_PATH="${QT6_DIR}/src"
    QT6_HOST_BUILD_PATH="${QT6_DIR}/host-build"
    QT6_HOST_STAGING_PATH="${QT6_DIR}/host"
    QT6_PI_BUILD_PATH="${QT6_DIR}/pi-build"

    cd /build
    mkdir -p \
        qt6 \
        qt6/host \
        /usr/local/qt6 \
        qt6/host-build \
        qt6/pi-build \
        qt6/src

    cd ${QT6_SRC_PATH}

    for QT_ARCHIVE_FILE in "${QT_ARCHIVE_FILES[@]}"; do
        if [ ! -f "${QT_ARCHIVE_FILE}" ]; then
            wget "${QT_DOWNLOAD_BASE_URL}/${QT_ARCHIVE_FILE}"
        else
            echo "File ${QT_ARCHIVE_FILE} already exists. Skipping download..."
        fi
    done

    cd ${QT6_HOST_BUILD_PATH}

    for QT_ARCHIVE_FILE in "${QT_ARCHIVE_FILES[@]}"; do
        tar xf ${QT6_SRC_PATH}/${QT_ARCHIVE_FILE}
    done

    echo "Compile Qt Base for the Host"
    cd ${QT6_HOST_BUILD_PATH}/qtbase-everywhere-src-${QT_VERSION}
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release \
        -DQT_BUILD_EXAMPLES=OFF \
        -DQT_BUILD_TESTS=OFF \
        -DQT_USE_CCACHE=ON \
        -DCMAKE_INSTALL_PREFIX=${QT6_HOST_STAGING_PATH}
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    echo "Compile Qt Shader Tools for the Host"
    cd ${QT6_HOST_BUILD_PATH}/qtshadertools-everywhere-src-${QT_VERSION}
    ${QT6_HOST_STAGING_PATH}/bin/qt-configure-module .
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    echo "Compile Qt Declarative for the Host"
    cd ${QT6_HOST_BUILD_PATH}/qtdeclarative-everywhere-src-${QT_VERSION}
    ${QT6_HOST_STAGING_PATH}/bin/qt-configure-module .
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    # TODO: Uncomment this block when ready.
    # echo "Compile Qt WebEngine for host"
    # cd ${QT6_HOST_BUILD_PATH}/qtwebengine-everywhere-src-${QT_VERSION}
    # ${QT6_HOST_STAGING_PATH}/bin/qt-configure-module .
    # cmake --build . --parallel "${CORE_COUNT}"
    # cmake --install .

    cd ${QT6_PI_BUILD_PATH}

    for QT_ARCHIVE_FILE in "${QT_ARCHIVE_FILES[@]}"; do
        tar xf ${QT6_SRC_PATH}/${QT_ARCHIVE_FILE}
    done

    echo "Compile Qt Base for the Raspberry Pi"
    cd ${QT6_PI_BUILD_PATH}/qtbase-everywhere-src-${QT_VERSION}
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release -DINPUT_opengl=es2 \
        -DQT_BUILD_EXAMPLES=OFF -DQT_BUILD_TESTS=OFF \
        -DQT_USE_CCACHE=ON \
        -DQT_HOST_PATH=${QT6_HOST_STAGING_PATH} \
        -DCMAKE_STAGING_PREFIX=${QT6_PI_STAGING_PATH} \
        -DCMAKE_INSTALL_PREFIX=/usr/local/qt6 \
        -DCMAKE_TOOLCHAIN_FILE=/build/toolchain.cmake \
        -DQT_FEATURE_xcb=ON -DFEATURE_xcb_xlib=ON \
        -DQT_FEATURE_xlib=ON -DFEATURE_xcb=ON -DFEATURE_eglfs=ON
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    echo "Compile Qt Shader Tools for the Raspberry Pi"
    cd ${QT6_PI_BUILD_PATH}/qtshadertools-everywhere-src-${QT_VERSION}
    ${QT6_PI_STAGING_PATH}/bin/qt-configure-module .
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    echo "Compile Qt Declarative for the Raspberry Pi"
    cd ${QT6_PI_BUILD_PATH}/qtdeclarative-everywhere-src-${QT_VERSION}
    ${QT6_PI_STAGING_PATH}/bin/qt-configure-module .
    cmake --build . --parallel "${CORE_COUNT}"
    cmake --install .

    # TODO: Uncomment this block when ready.
    # echo "Compile Qt WebEngine for the Raspberry Pi"
    # cd ${QT6_PI_BUILD_PATH}/qtwebengine-everywhere-src-${QT_VERSION}
    # ${QT6_PI_STAGING_PATH}/bin/qt-configure-module .
    # cmake --build . --parallel "${CORE_COUNT}"
    # cmake --install .

    echo "Compilation is finished"
}

function create_qt_archive() {
    local ARCHIVE_NAME="qt${QT_MAJOR}-${QT_VERSION}-${DEBIAN_VERSION}-pi4.tar.gz"
    local ARCHIVE_DESTINATION="/build/release/${ARCHIVE_NAME}"

    cd /build
    mkdir -p release && cd release

    cd /usr/local
    tar cfz ${ARCHIVE_DESTINATION} qt6

    # TODO: Uncomment this block when ready.
    # cd /build/release
    # sha256sum ${ARCHIVE_NAME} > ${ARCHIVE_DESTINATION}.sha256
}

function create_hello_gui_archive() {
    local ARCHIVE_NAME="hello-gui.tar.gz"
    local ARCHIVE_DESTINATION="/build/release/${ARCHIVE_NAME}"

    cp -rf /src/examples/hello-2 /build
    cd /build/hello-2
    mkdir -p build && cd build
    ${QT6_PI_STAGING_PATH}/bin/qt-cmake ..
    cmake --build . --parallel ${CORE_COUNT}

    mkdir -p fakeroot/bin
    mv Hello fakeroot/bin
    cd fakeroot

    tar cfz ${ARCHIVE_DESTINATION} .

    # TODO: Uncomment this block when ready.
    # cd /build/release
    # sha256sum ${ARCHIVE_NAME} > ${ARCHIVE_DESTINATION}.sha256
}

function main() {
    setup_sysroot
    copy_toolchain_cmake

    fix_symbolic_links
    install_qt

    create_qt_archive

    create_hello_gui_archive
}

main
