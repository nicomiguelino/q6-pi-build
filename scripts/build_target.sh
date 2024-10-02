#!/bin/bash

set -euo pipefail

export TARGET_DEVICE="pi4"
export TARGET_PLATFORM="linux/arm/v8"

BUILDX_ARGS=(
    "--platform" "$TARGET_PLATFORM"
    "--load"
    "-f" "docker/Dockerfile.arm.$TARGET_DEVICE"
    "-t" "target-$TARGET_DEVICE"
)

docker buildx build "${BUILDX_ARGS[@]}" .
docker rm "temp-target-$TARGET_DEVICE" || true
docker create --name "temp-target-$TARGET_DEVICE" "target-$TARGET_DEVICE"
docker cp "temp-target-$TARGET_DEVICE:/build/rasp.tar.gz" ./rasp.tar.gz
