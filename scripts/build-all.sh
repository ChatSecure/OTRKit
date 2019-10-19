#!/bin/bash
set -e

cd "`dirname \"$0\"`"
TOPDIR=$(pwd)

# Combine build results of different archs into one
export FINAL_BUILT_DIR="${TOPDIR}/../OTRKitDependencies/"
mkdir -p "${FINAL_BUILT_DIR}"
export LIBOTRKIT_XCFRAMEWORK="${FINAL_BUILT_DIR}/libotrkit.xcframework"

if [ -d "${LIBOTRKIT_XCFRAMEWORK}" ]; then
  echo "Final libotrkit.xcframework found, skipping build..."
  exit 0
fi

PLATFORM_TARGET="macOS" ./build-libs.sh
PLATFORM_TARGET="iOS" ./build-libs.sh
./build-xcframework.sh
