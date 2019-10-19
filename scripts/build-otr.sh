#!/bin/bash
set -e

if [ ! -e "libotr-${LIBOTR_VERSION}.tar.gz" ]; then
   curl -LO "https://otr.cypherpunks.ca/libotr-${LIBOTR_VERSION}.tar.gz"  --retry 5
fi

# Extract source
rm -rf "libotr-${LIBOTR_VERSION}"
tar zxf "libotr-${LIBOTR_VERSION}.tar.gz"

pushd "libotr-${LIBOTR_VERSION}"

   LDFLAGS="-L${ARCH_BUILT_LIBS_DIR} -fPIE ${PLATFORM_VERSION_MIN}"
   CFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"
   CPPFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"

   if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
      then
      EXTRA_CONFIG="--host ${ARCH}-apple-darwin"
   else
      EXTRA_CONFIG="--host=arm-apple-darwin"
   fi

   ./configure --disable-shared --enable-static --with-pic ${EXTRA_CONFIG} \
   --with-sysroot="${SDK_PATH}" \
   --with-libgcrypt-prefix="${ARCH_BUILT_DIR}" \
   --prefix="${ROOTDIR}" \
   LDFLAGS="${LDFLAGS}" \
   CFLAGS="${CFLAGS}" \
   CPPLAGS="${CPPFLAGS}"

   make
   make install

   # Copy the build results        
   cp "${ROOTDIR}/lib/libotr.a" "${ARCH_BUILT_LIBS_DIR}"
   cp -R ${ROOTDIR}/include/* "${ARCH_BUILT_HEADERS_DIR}"
   cp -R ${ROOTDIR}/bin/* "${ARCH_BUILT_BIN_DIR}"

popd

# Clean up
rm -rf "libotr-${LIBOTR_VERSION}"