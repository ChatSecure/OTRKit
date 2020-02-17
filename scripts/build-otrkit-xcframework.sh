#!/bin/bash

# User variables
# VARIABLE : valid options

set -e

cd "`dirname \"$0\"`"
TOPDIR=$(pwd)

# Combine build results of different archs into one
FINAL_BUILT_DIR="${TOPDIR}/../OTRKitDependencies/"
mkdir -p "${FINAL_BUILT_DIR}"
OTRKIT_XCFRAMEWORK="${FINAL_BUILT_DIR}/OTRKit.xcframework"
OTRKIT_STATIC_XCFRAMEWORK="${FINAL_BUILT_DIR}/OTRKitStatic.xcframework"

if [ -d "${OTRKIT_XCFRAMEWORK}" ] && [ -d "${OTRKIT_STATIC_XCFRAMEWORK}" ]; then
  echo "Final xcframeworks found, skipping build..."
  exit 0
fi

BUILT_DIR="${TOPDIR}/built"
if [ ! -d "${BUILT_DIR}" ]; then
  mkdir -p "${BUILT_DIR}"
fi

ARCHIVES_DIR="${BUILT_DIR}/archives"
if [ ! -d "${ARCHIVES_DIR}" ]; then
  mkdir -p "${ARCHIVES_DIR}"
fi

XCFRAMEWORK_INPUTS=""

function archiveFramework {
  xcrun xcodebuild archive \
    -project ../OTRKit.xcodeproj \
    -scheme "${1}" \
    -destination "${2}" \
    -archivePath "${3}" \
    MACH_O_TYPE=mh_dylib \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

function archiveLibrary {
  xcrun xcodebuild archive \
    -project ../OTRKit.xcodeproj \
    -scheme "${1}" \
    -destination "${2}" \
    -archivePath "${3}" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES
}

IOS_ARCHIVE_DIR="${ARCHIVES_DIR}/iOS"
IOS_SIMULATOR_ARCHIVE_DIR="${ARCHIVES_DIR}/iOS-Simulator"
IOS_CATALYST_ARCHIVE_DIR="${ARCHIVES_DIR}/iOS-Catalyst"
MACOS_ARCHIVE_DIR="${ARCHIVES_DIR}/macOS"

# Creates xc framework
function createXCFramework {
  FRAMEWORK_ARCHIVE_PATH_POSTFIX=".xcarchive/Products/Library/Frameworks"
  FRAMEWORK_SIMULATOR_DIR="${IOS_SIMULATOR_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_DEVICE_DIR="${IOS_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_CATALYST_DIR="${IOS_CATALYST_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_MAC_DIR="${MACOS_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  xcodebuild -create-xcframework \
            -framework "${FRAMEWORK_SIMULATOR_DIR}/${1}.framework" \
            -framework "${FRAMEWORK_DEVICE_DIR}/${1}.framework" \
            -framework "${FRAMEWORK_CATALYST_DIR}/${1}.framework" \
            -framework "${FRAMEWORK_MAC_DIR}/${1}.framework" \
            -output "${OTRKIT_XCFRAMEWORK}"
}

# Creates xc framework
function createStaticXCFramework {
  FRAMEWORK_ARCHIVE_PATH_POSTFIX=".xcarchive/Products/usr/local"

  FRAMEWORK_SIMULATOR_DIR="${IOS_SIMULATOR_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_DEVICE_DIR="${IOS_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_CATALYST_DIR="${IOS_CATALYST_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  FRAMEWORK_MAC_DIR="${MACOS_ARCHIVE_DIR}${FRAMEWORK_ARCHIVE_PATH_POSTFIX}"
  xcodebuild -create-xcframework \
            -library "${FRAMEWORK_SIMULATOR_DIR}/lib/lib${1}.a" -headers "${FRAMEWORK_SIMULATOR_DIR}/include/lib${1}.a" \
            -library "${FRAMEWORK_DEVICE_DIR}/lib/lib${1}.a" -headers "${FRAMEWORK_DEVICE_DIR}/include/lib${1}.a" \
            -library "${FRAMEWORK_CATALYST_DIR}/lib/lib${1}.a" -headers "${FRAMEWORK_CATALYST_DIR}/include/lib${1}.a" \
            -library "${FRAMEWORK_MAC_DIR}/lib/lib${1}.a" -headers "${FRAMEWORK_MAC_DIR}/include/lib${1}.a" \
            -output "${OTRKIT_STATIC_XCFRAMEWORK}"
}

archiveFramework "OTRKit (iOS)" "generic/platform=iOS" "${IOS_ARCHIVE_DIR}"
archiveFramework "OTRKit (iOS)" "generic/platform=iOS Simulator" "${IOS_SIMULATOR_ARCHIVE_DIR}"
archiveFramework "OTRKit (iOS)" "generic/platform=macOS" "${IOS_CATALYST_ARCHIVE_DIR}"
archiveFramework "OTRKit (macOS)" "generic/platform=macOS" "${MACOS_ARCHIVE_DIR}"

createXCFramework OTRKit

archiveLibrary "OTRKit Static (iOS)" "generic/platform=iOS" "${IOS_ARCHIVE_DIR}"
archiveLibrary "OTRKit Static (iOS)" "generic/platform=iOS Simulator" "${IOS_SIMULATOR_ARCHIVE_DIR}"
archiveLibrary "OTRKit Static (iOS)" "generic/platform=macOS" "${IOS_CATALYST_ARCHIVE_DIR}"
archiveLibrary "OTRKit Static (macOS)" "generic/platform=macOS" "${MACOS_ARCHIVE_DIR}"

createStaticXCFramework OTRKit

echo "Success! Finished building OTRKit xcframeworks."