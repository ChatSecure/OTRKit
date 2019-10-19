#!/bin/bash

# User variables
# VARIABLE : valid options
# ARCHS : x86_64 x86_64-simulator x86_64-maccatalyst arm64

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

BUILT_DIR="${TOPDIR}/built"
if [ ! -d "${BUILT_DIR}" ]; then
  mkdir -p "${BUILT_DIR}"
fi

if [ -n "${ARCHS}" ]; then
  echo "Linking user-defined architectures: ${ARCHS}"
else
  ARCHS="x86_64 x86_64-simulator x86_64-maccatalyst arm64"
  echo "Linking architectures: ${ARCHS}"
fi

# Combine binaries of different architectures results
BINS=(libgpg-error.a)
BINS+=(libgcrypt.a)
BINS+=(libotr.a)

NUMBER_OF_BUILT_ARCHS=${#ARCHS[@]}

XCFRAMEWORK_INPUTS=""


for ARCH in ${ARCHS}; do
  ARCH_DIR="${BUILT_DIR}/${ARCH}"
  LIB_DIR="${ARCH_DIR}/lib"
  LIBOTRKIT="${LIB_DIR}/libotrkit.a"
  xcrun libtool -static -o "${LIBOTRKIT}" "${LIB_DIR}/libgpg-error.a" "${LIB_DIR}/libgcrypt.a" "${LIB_DIR}/libotr.a"
  XCFRAMEWORK_INPUTS+="-library ${LIBOTRKIT} -headers ${ARCH_DIR}/include "
done

FINAL_BUILT_DIR="${TOPDIR}/../OTRKitDependencies"
mkdir -p "${FINAL_BUILT_DIR}"
LIBOTRKIT_XCFRAMEWORK="${FINAL_BUILT_DIR}/libotrkit.xcframework"

xcrun xcodebuild -create-xcframework ${XCFRAMEWORK_INPUTS} -output "${LIBOTRKIT_XCFRAMEWORK}"

echo "Success! Finished building xcframework."