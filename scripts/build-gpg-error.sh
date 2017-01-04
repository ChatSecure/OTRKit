#!/bin/bash
set -e

if [ ! -e "libgpg-error-${LIBGPG_ERROR_VERSION}.tar.bz2" ]; then
	curl -LO "https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-${LIBGPG_ERROR_VERSION}.tar.bz2"  --retry 5
fi

# Extract source
rm -rf "libgpg-error-${LIBGPG_ERROR_VERSION}"
tar zxf "libgpg-error-${LIBGPG_ERROR_VERSION}.tar.bz2"

pushd "libgpg-error-${LIBGPG_ERROR_VERSION}"

   LDFLAGS="-L${ARCH_BUILT_LIBS_DIR} -fPIE ${PLATFORM_VERSION_MIN}"
   CFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"
   CPPFLAGS=" -arch ${ARCH} -fPIE -isysroot ${SDK_PATH} -I${ARCH_BUILT_HEADERS_DIR} ${PLATFORM_VERSION_MIN}"

   if [ "${ARCH}" == "i386" ] || [ "${ARCH}" == "x86_64" ];
   	then
      EXTRA_CONFIG="--host ${ARCH}-apple-darwin"
	else
		if [ "${ARCH}" == "arm64" ] ; then
            EXTRA_CONFIG="--host aarch64-apple-darwin"
      else
            EXTRA_CONFIG="--host arm-apple-darwin"
      fi
	fi

   ./configure --disable-shared --enable-static --with-pic --enable-threads=posix ${EXTRA_CONFIG} \
   --with-sysroot="${SDK_PATH}" \
   --prefix="${ROOTDIR}" \
   LDFLAGS="${LDFLAGS}" \
   CFLAGS="${CFLAGS}" \
   CPPLAGS="${CPPFLAGS}"

   make
   make install

   # Copy the build results
   cp "${ROOTDIR}/lib/libgpg-error.a" "${ARCH_BUILT_LIBS_DIR}/libgpg-error.a"
   cp -R ${ROOTDIR}/include/* "${ARCH_BUILT_HEADERS_DIR}"
   cp -R ${ROOTDIR}/bin/* "${ARCH_BUILT_BIN_DIR}"

popd

# Clean up
rm -rf "libgpg-error-${LIBGPG_ERROR_VERSION}"