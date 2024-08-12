#!/bin/bash

set -euo pipefail

export BASE_IMAGE_TAG="bookworm"
export TARGET_DEVICE=${TARGET_DEVICE:-"x86"}

if [[ ! $TARGET_DEVICE =~ ^(pi3|pi4|pi5|x86)$ ]]; then
    echo "Invalid target device: $TARGET_DEVICE"
    echo "Supported devices: pi3, pi4, pi5, x86"
    exit 1
fi

function main() {
    if [[ "$TARGET_DEVICE" == "pi3" ]]; then
        export BASE_IMAGE_NAME="balenalib/raspberrypi3-debian"
    elif [[ "$TARGET_DEVICE" == "pi4" ]]; then
        export BASE_IMAGE_NAME="balenalib/raspberrypi4-64-debian"
    elif [[ "$TARGET_DEVICE" == "pi5" ]]; then
        export BASE_IMAGE_NAME="balenalib/raspberrypi5-debian"
    elif [[ "$TARGET_DEVICE" == "x86" ]]; then
        export BASE_IMAGE_NAME="balenalib/intel-nuc-debian"
    fi

    cat docker/Dockerfile.pi.template | envsubst > docker/Dockerfile.pi
}

main
