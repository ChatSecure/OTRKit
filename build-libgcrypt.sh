#!/bin/bash
#  Builds libgcrypt for all three current iPhone targets: iPhoneSimulator-i386,
#  iPhoneOS-armv6, iPhoneOS-armv7.
#
#  Copyright 2012 Mike Tigas <mike@tig.as>
#
#  Based on work by Felix Schulze on 16.12.10.
#  Copyright 2010 Felix Schulze. All rights reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#
###########################################################################
#  Choose your libgcrypt version and your currently-installed iOS SDK version:
#
VERSION="1.5.4"
SDKVERSION=`xcrun --sdk iphoneos --show-sdk-version 2> /dev/null`
MINIOSVERSION="7.0"
VERIFYGPG=true

#
#
###########################################################################
#
# Don't change anything under this line!
#
###########################################################################

# No need to change this since xcode build will only compile in the
# necessary bits from the libraries we create
ARCHS="i386 x86_64 armv7 armv7s arm64"

if [ "$1" == "--noverify" ]; then
  VERIFYGPG=false
fi
if [ "$2" == "--i386only" ]; then
  ARCHS="i386"
fi

DEVELOPER=`xcode-select -print-path`

cd "`dirname \"$0\"`"
REPOROOT=$(pwd)

# Where we'll end up storing things in the end
OUTPUTDIR="${REPOROOT}/dependencies"
mkdir -p ${OUTPUTDIR}/include
mkdir -p ${OUTPUTDIR}/lib
mkdir -p ${OUTPUTDIR}/bin


BUILDDIR="${REPOROOT}/build"

# where we will keep our sources and build from.
SRCDIR="${BUILDDIR}/src"
mkdir -p $SRCDIR
# where we will store intermediary builds
INTERDIR="${BUILDDIR}/built"
mkdir -p $INTERDIR

########################################

cd $SRCDIR

# Exit the script if an error happens
set -e

if [ ! -e "${SRCDIR}/libgcrypt-${VERSION}.tar.bz2" ]; then
	echo "Downloading libgcrypt-${VERSION}.tar.bz2"
    curl --retry 10 -LO ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-${VERSION}.tar.bz2
else
	echo "Using libgcrypt-${VERSION}.tar.bz2"
fi

# see https://www.openssl.org/about/,
# up to you to set up `gpg` and add keys to your keychain
if $VERIFYGPG; then
    if [ ! -e "${SRCDIR}/libgcrypt-${VERSION}.tar.bz2.sig" ]; then
        curl -O ftp://ftp.gnupg.org/gcrypt/libgcrypt/libgcrypt-${VERSION}.tar.bz2.sig
    fi
    echo "Using libgcrypt-${VERSION}.tar.bz2.sig"
    if out=$(gpg --status-fd 1 --verify "libgcrypt-${VERSION}.tar.bz2.sig" "libgcrypt-${VERSION}.tar.bz2" 2>/dev/null) &&
    echo "$out" | grep -qs "^\[GNUPG:\] VALIDSIG"; then
        echo "$out" | egrep "GOODSIG|VALIDSIG"
        echo "Verified GPG signature for source..."
    else
        echo "$out" >&2
        echo "COULD NOT VERIFY PACKAGE SIGNATURE..."
        exit 1
    fi
fi

tar zxf libgcrypt-${VERSION}.tar.bz2 -C $SRCDIR
cd "${SRCDIR}/libgcrypt-${VERSION}"

set +e # don't bail out of bash script if ccache doesn't exist
CCACHE=`which ccache`
if [ $? == "0" ]; then
    echo "Building with ccache: $CCACHE"
    CCACHE="${CCACHE} "
else
    echo "Building without ccache"
    CCACHE=""
fi
set -e # back to regular "bail out on error" mode

for ARCH in ${ARCHS}
do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ] ; then
        PLATFORM="iPhoneSimulator"
        EXTRA_CONFIG="--host ${ARCH}-apple-darwin"
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_LDFLAGS="-arch ${ARCH}"
    else
        PLATFORM="iPhoneOS"
        if [ "${ARCH}" == "arm64" ] ; then
            EXTRA_CONFIG="--host aarch64-apple-darwin"
        else
            EXTRA_CONFIG="--host arm-apple-darwin"
        fi
        EXTRA_CFLAGS="-arch ${ARCH}"
        EXTRA_LDFLAGS="-arch ${ARCH}"
    fi

	mkdir -p "${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk"

	./configure --disable-asm --disable-shared --enable-static \
    --disable-aesni-support --disable-padlock-support \
    --with-pic --with-gpg-error-prefix=${OUTPUTDIR} ${EXTRA_CONFIG} \
    --prefix="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk" \
    --with-sysroot=${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk \
    LDFLAGS="$LDFLAGS -fPIE ${EXTRA_LDFLAGS} -L${OUTPUTDIR}/lib" \
    CFLAGS="$CFLAGS -g -DNO_ASM ${EXTRA_CFLAGS} -fPIE -miphoneos-version-min=${MINIOSVERSION} -I${OUTPUTDIR}/include -isysroot ${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer/SDKs/${PLATFORM}${SDKVERSION}.sdk" \
    # Build the application and install it to the fake SDK intermediary dir
    # we have set up. Make sure to clean up afterward because we will re-use
    # this source tree to cross-compile other targets.
	make
	make install
	make clean
done

########################################

echo "Build library..."

# These are the libs that comprise libgcrypt.
OUTPUT_LIBS="libgcrypt.a"
for OUTPUT_LIB in ${OUTPUT_LIBS}; do
    INPUT_LIBS=""
    for ARCH in ${ARCHS}; do
        if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ] ; then
            PLATFORM="iPhoneSimulator"
        else
            PLATFORM="iPhoneOS"
        fi
        INPUT_ARCH_LIB="${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/lib/${OUTPUT_LIB}"
        if [ -e $INPUT_ARCH_LIB ]; then
            INPUT_LIBS="${INPUT_LIBS} ${INPUT_ARCH_LIB}"
        fi
    done
    # Combine the three architectures into a universal library.
    if [ -n "$INPUT_LIBS"  ]; then
        lipo -create $INPUT_LIBS \
        -output "${OUTPUTDIR}/lib/${OUTPUT_LIB}"
    else
        echo "$OUTPUT_LIB does not exist, skipping (are the dependencies installed?)"
    fi
done

for ARCH in ${ARCHS}; do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ] ; then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi
    cp -R ${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/include/* ${OUTPUTDIR}/include/
    if [ $? == "0" ]; then
        # We only need to copy the headers over once. (So break out of forloop
        # once we get first success.)
        break
    fi
done

for ARCH in ${ARCHS}; do
    if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ] ; then
        PLATFORM="iPhoneSimulator"
    else
        PLATFORM="iPhoneOS"
    fi
    cp -R ${INTERDIR}/${PLATFORM}${SDKVERSION}-${ARCH}.sdk/bin/* ${OUTPUTDIR}/bin/
    if [ $? == "0" ]; then
        # We only need to copy the binaries over once. (So break out of forloop
        # once we get first success.)
        break
    fi
done

####################

echo "Building done."
echo "Cleaning up..."
rm -fr ${INTERDIR}
rm -fr "${SRCDIR}/libgcrypt-${VERSION}"
echo "Done."
