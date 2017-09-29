#!/bin/bash
set -e

if [ ! -e "libgcrypt-${LIBGCRYPT_VERSION}.tar.bz2" ]; then
   curl -LO "https://gnupg.org/ftp/gcrypt/libgcrypt/libgcrypt-${LIBGCRYPT_VERSION}.tar.bz2"  --retry 5
fi

# Extract source
rm -rf "libgcrypt-${LIBGCRYPT_VERSION}"
tar zxf "libgcrypt-${LIBGCRYPT_VERSION}.tar.bz2"

pushd "libgcrypt-${LIBGCRYPT_VERSION}"

   # Apply patches
   patch < "${TOPDIR}/patches/gcrypt-disable-tests.diff" Makefile.in
   # The below patches attempt to fix the arm64 assembly compilation with Xcode 9, but do not work
   # patch < "${TOPDIR}/patches/gcrypt-mpih-add1.S.diff" mpi/aarch64/mpih-add1.S
   # patch < "${TOPDIR}/patches/gcrypt-mpih-mul1.S.diff" mpi/aarch64/mpih-mul1.S
   # patch < "${TOPDIR}/patches/gcrypt-mpih-mul2.S.diff" mpi/aarch64/mpih-mul2.S
   # patch < "${TOPDIR}/patches/gcrypt-mpih-mul3.S.diff" mpi/aarch64/mpih-mul3.S
   # patch < "${TOPDIR}/patches/gcrypt-mpih-sub1.S.diff" mpi/aarch64/mpih-sub1.S

   LDFLAGS="-L${ARCH_BUILT_LIBS_DIR} -fPIE ${PLATFORM_VERSION_MIN}"
   CFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"
   CPPFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"

   if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
      then
      EXTRA_CONFIG="--host ${ARCH}-apple-darwin"
   else
      if [ "${ARCH}" == "arm64" ] ; then
            # We must disable arm64 assembly with Xcode 9
            EXTRA_CONFIG="--host aarch64-apple-darwin --disable-asm"
      else
            EXTRA_CONFIG="--host arm-apple-darwin"
      fi
   fi

   # Without setting the path, libgcrypt cannot find libgpg-error-config for some reason
   PATH="${PATH}:${ARCH_BUILT_BIN_DIR}"
   ./configure --disable-shared --enable-static --with-pic --enable-threads=posix ${EXTRA_CONFIG} \
   --with-sysroot="${SDK_PATH}" \
   --with-libgpg-error-prefix="${ARCH_BUILT_DIR}" \
   --prefix="${ROOTDIR}" \
   LDFLAGS="${LDFLAGS}" \
   CFLAGS="${CFLAGS}" \
   CPPLAGS="${CPPFLAGS}" \


   make
   make install

   # Copy the build results        
   cp "${ROOTDIR}/lib/libgcrypt.a" "${ARCH_BUILT_LIBS_DIR}"
   cp -R ${ROOTDIR}/include/* "${ARCH_BUILT_HEADERS_DIR}"
   cp -R ${ROOTDIR}/bin/* "${ARCH_BUILT_BIN_DIR}"

popd

# Clean up
rm -rf "libgcrypt-${LIBGCRYPT_VERSION}"