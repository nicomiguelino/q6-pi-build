#!/bin/bash

set -euo pipefail

export TARGET_DEVICE="pi4"

BUILD_ARGS=(
    "-f" "docker/Dockerfile.cross.$TARGET_DEVICE"
    "-t" "cross-$TARGET_DEVICE"
)

RUN_ARGS=(
    "-itd"
    "--name" "temp-cross-$TARGET_DEVICE"
    "-v" "$PWD/build:/build:Z"
    "-v" "./scripts/build_qt6.sh:/scripts/build_qt6.sh"
    "-v" "./opt/cross-pi-gcc:/opt/cross-pi-gcc"
    "cross-$TARGET_DEVICE"
)

docker build "${BUILD_ARGS[@]}" .
docker rm -f "temp-cross-$TARGET_DEVICE" || true
docker run "${RUN_ARGS[@]}" bash
