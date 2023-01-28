#!/bin/bash

set -eux

ZSTD_VERSION=1.5.2
GMP_VERSION=6.2.1
MPFR_VERSION=4.1.0
MPC_VERSION=1.2.1
ISL_VERSION=0.25
EXPAT_VERSION=2.4.8
BINUTILS_VERSION=2.39
GCC_VERSION=12.2.0
MAKE_VERSION=4.2.1
PYTHON_VERSION=3.8.16
GDB_VERSION=12.1

# set HOST env variable to i686-w64-mingw32 if you want to get 32-bit windows binaries
HOST=${HOST:-x86_64-w64-mingw32}

ARG=${1:-64}
if [ "${ARG}" == "32" ]; then
  TARGET=arm-none-eabi
elif [ "${ARG}" == "64" ]; then
  TARGET=aarch64-none-elf
else
  exit 1
fi

NAME=gcc-v${GCC_VERSION}-${TARGET}

function get()
{
  mkdir -p ${SOURCE} && pushd ${SOURCE}
  FILE="${1##*/}"
  if [ ! -f "${FILE}" ]; then
    curl -fL "$1" -o ${FILE}
    case "${1##*.}" in
    gz|tgz)
      tar --warning=none -xzf ${FILE}
      ;;
    bz2)
      tar --warning=none -xjf ${FILE}
      ;;
    xz)
      tar --warning=none -xJf ${FILE}
      ;;
    *)
      exit 1
      ;;
    esac
  fi
  popd
}

# by default place output in current folder
OUTPUT="${OUTPUT:-`pwd`}"

# place where source code is downloaded & unpacked
SOURCE=`pwd`/source

# place where build for specific target is done
BUILD=`pwd`/build/${TARGET}

# place where bootstrap compiler is built
BOOTSTRAP=`pwd`/bootstrap/${TARGET}

# place where build dependencies are installed
PREFIX=`pwd`/prefix/${TARGET}

# final installation folder
FINAL=`pwd`/${NAME}


if [ -n "$ZSTD_VERSION" ]; then
  get https://github.com/facebook/zstd/releases/download/v${ZSTD_VERSION}/zstd-${ZSTD_VERSION}.tar.gz
fi
if [ -n "$GMP_VERSION" ]; then
  get https://ftp.gnu.org/gnu/gmp/gmp-${GMP_VERSION}.tar.xz
fi
if [ -n "$MPFR_VERSION" ]; then
  get https://ftp.gnu.org/gnu/mpfr/mpfr-${MPFR_VERSION}.tar.xz
fi
if [ -n "$MPC_VERSION" ]; then
  get https://ftp.gnu.org/gnu/mpc/mpc-${MPC_VERSION}.tar.gz
fi
if [ -n "$ISL_VERSION" ]; then
  get https://libisl.sourceforge.io/isl-${ISL_VERSION}.tar.xz
fi
if [ -n "$EXPAT_VERSION" ]; then
  get https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VERSION//./_}/expat-${EXPAT_VERSION}.tar.xz
fi
if [ -n "$BINUTILS_VERSION" ]; then
  get https://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.xz
fi
if [ -n "$GCC_VERSION" ]; then
  get https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
fi
if [ -n "$PYTHON_VERSION" ]; then
  get https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz
fi
if [ -n "$GDB_VERSION" ]; then
  get https://ftp.gnu.org/gnu/gdb/gdb-${GDB_VERSION}.tar.xz
fi
if [ -n "$MAKE_VERSION" ]; then
  get https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.bz2
fi

if [ -n "$BINUTILS_VERSION" ]; then
  mkdir -p ${BUILD}/x-binutils && pushd ${BUILD}/x-binutils
  ${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
    --prefix=${BOOTSTRAP}                          \
    --target=${TARGET}                             \
    --disable-plugins                              \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-werror                               \
    --with-sysroot
  make -j`nproc`
  make install
  popd
fi

if [ -n "$GCC_VERSION" ]; then
  mkdir -p ${BUILD}/x-gcc && pushd ${BUILD}/x-gcc
  ${SOURCE}/gcc-${GCC_VERSION}/configure \
    --prefix=${BOOTSTRAP}                \
    --target=${TARGET}                   \
    --enable-static                      \
    --disable-shared                     \
    --disable-lto                        \
    --disable-nls                        \
    --disable-multilib                   \
    --disable-werror                     \
    --disable-libgomp                    \
    --enable-languages=c,c++             \
    --enable-checking=release            \
    --without-headers
  make -j`nproc` all-gcc
  make install-gcc
  popd
fi

export PATH=${BOOTSTRAP}/bin:$PATH



if [ -n "$PYTHON_VERSION" ]; then
  mkdir -p ${BUILD}/python && pushd ${BUILD}/python
  ${SOURCE}/Python-${PYTHON_VERSION}/configure \
    --host=${HOST}                       \
    --build=x86_64-pc-linux-gnu          \
    --with-build-python=python3          \
    --disable-test-modules               \
    --enable-shared
  make -j`nproc`
  make install
  popd
fi

if [ -n "$ZSTD_VERSION" ]; then
  mkdir -p ${BUILD}/zstd && pushd ${BUILD}/zstd
  cmake ${SOURCE}/zstd-${ZSTD_VERSION}/build/cmake \
    -DCMAKE_BUILD_TYPE=Release                     \
    -DCMAKE_SYSTEM_NAME=Windows                    \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}               \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER      \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY       \
    -DCMAKE_C_COMPILER=${HOST}-gcc                 \
    -DCMAKE_CXX_COMPILER=${HOST}-g++               \
    -DZSTD_BUILD_STATIC=ON                         \
    -DZSTD_BUILD_SHARED=OFF                        \
    -DZSTD_BUILD_PROGRAMS=OFF                      \
    -DZSTD_BUILD_CONTRIB=OFF                       \
    -DZSTD_BUILD_TESTS=OFF
  make -j`nproc`
  make install
  popd
fi

if [ -n "$GMP_VERSION" ]; then
  mkdir -p ${BUILD}/gmp && pushd ${BUILD}/gmp
  ${SOURCE}/gmp-${GMP_VERSION}/configure \
    --prefix=${PREFIX}                   \
    --host=${HOST}                     \
    --disable-shared                     \
    --enable-static                      \
    --enable-fat
  make -j`nproc`
  make install
  popd
fi

if [ -n "$MPFR_VERSION" ]; then
  mkdir -p ${BUILD}/mpfr && pushd ${BUILD}/mpfr
  ${SOURCE}/mpfr-${MPFR_VERSION}/configure \
    --prefix=${PREFIX}                     \
    --host=${HOST}                      \
    --disable-shared                       \
    --enable-static                        \
    --with-gmp-build=${BUILD}/gmp
  make -j`nproc`
  make install
  popd
fi

if [ -n "$MPC_VERSION" ]; then
  mkdir -p ${BUILD}/mpc && pushd ${BUILD}/mpc
  ${SOURCE}/mpc-${MPC_VERSION}/configure \
    --prefix=${PREFIX}                   \
    --host=${HOST}                      \
    --disable-shared                     \
    --enable-static                      \
    --with-{gmp,mpfr}=${PREFIX}
  make -j`nproc`
  make install
  popd
fi

if [ -n "$ISL_VERSION" ]; then
  mkdir -p ${BUILD}/isl && pushd ${BUILD}/isl
  ${SOURCE}/isl-${ISL_VERSION}/configure \
    --prefix=${PREFIX}                   \
    --host=${HOST}                      \
    --disable-shared                     \
    --enable-static                      \
    --with-gmp-prefix=${PREFIX}
  make -j`nproc`
  make install
  popd
fi

if [ -n "$EXPAT_VERSION" ]; then
  mkdir -p ${BUILD}/expat && pushd ${BUILD}/expat
  ${SOURCE}/expat-${EXPAT_VERSION}/configure \
    --prefix=${PREFIX}                       \
    --host=${HOST}                           \
    --disable-shared                         \
    --enable-static                          \
    --without-examples                       \
    --without-tests
  make -j`nproc`
  make install
  popd
fi

if [ -n "$BINUTILS_VERSION" ]; then
  mkdir -p ${BUILD}/binutils && pushd ${BUILD}/binutils
  ${SOURCE}/binutils-${BINUTILS_VERSION}/configure \
    --prefix=${FINAL}                              \
    --target=${TARGET}                             \
    --host=${HOST}                                 \
    --enable-lto                                   \
    --enable-plugins                               \
    --disable-nls                                  \
    --disable-multilib                             \
    --disable-werror                               \
    --with-sysroot                                 \
    --with-{gmp,mpfr,mpc,isl}=${PREFIX}
  make -j`nproc`
  make install
  popd
fi

if [ -n "$GCC_VERSION" ]; then
  mkdir -p ${BUILD}/gcc && pushd ${BUILD}/gcc
  ${SOURCE}/gcc-${GCC_VERSION}/configure \
    --prefix=${FINAL}                    \
    --target=${TARGET}                   \
    --host=${HOST}                       \
    --disable-dependency-tracking        \
    --disable-nls                        \
    --disable-multilib                   \
    --disable-werror                     \
    --disable-shared                     \
    --enable-static                      \
    --enable-lto                         \
    --enable-languages=c,c++,lto         \
    --enable-checking=release            \
    --enable-mingw-wildcard              \
    --disable-win32-registry             \
    --without-headers                    \
    --with-{gmp,mpfr,mpc,isl,zstd}=${PREFIX}
  make -j`nproc` all-gcc all-target-libgcc
  make install-gcc install-target-libgcc
  popd
fi

if [ -n "$GDB_VERSION" ]; then
  mkdir -p ${BUILD}/gdb && pushd ${BUILD}/gdb
  ${SOURCE}/gdb-${GDB_VERSION}/configure \
    --prefix=${FINAL}                    \
    --host=${HOST}                       \
    --target=${TARGET}                   \
    --disable-werror                     \
    --disable-source-highlight           \
    --with-mpfr                          \
    --with-expat                         \
    --with-python                        \
    --enable-sim                         \
    --with-libgmp-prefix=${PREFIX}       \
    --with-libmpfr-prefix=${PREFIX}      \
    --with-libexpat-prefix=${PREFIX}     \
    --with-static-standard-libraries
  make -j`nproc`
  cp gdb/gdb.exe ${FINAL}/bin/
  popd
fi

if [ -n "$MAKE_VERSION" ]; then
  mkdir -p ${BUILD}/make && pushd ${BUILD}/make
  ${SOURCE}/make-${MAKE_VERSION}/configure \
    --prefix=${FINAL}                      \
    --host=${HOST}                         \
    --disable-nls                          \
    --disable-rpath                        \
    --enable-case-insensitive-file-system
  make -j`nproc`
  make install
  popd
fi

rm -rf ${FINAL}/bin/${TARGET}-ld.bfd.exe ${FINAL}/${TARGET}/bin/ld.bfd.exe
rm -rf ${FINAL}/lib/bfd-plugins/libdep.dll.a
rm -rf ${FINAL}/share

find ${FINAL}     -name '*.exe' -print0 | xargs -0 -n 8 ${HOST}-strip --strip-unneeded
find ${FINAL}     -name '*.dll' -print0 | xargs -0 -n 8 ${HOST}-strip --strip-unneeded
find ${FINAL}     -name '*.o'   -print0 | xargs -0 -n 8 ${TARGET}-strip --strip-unneeded
find ${FINAL}/lib -name '*.a'   -print0 | xargs -0 -n 8 -P `nproc` ${TARGET}-strip --strip-unneeded

7zr a -mx9 -mqs=on -mmt=on ${OUTPUT}/${NAME}.7z ${FINAL}

if [[ -v GITHUB_WORKFLOW ]]; then
  if [ -n "$GCC_VERSION" ]; then
    echo "::set-output name=GCC_VERSION::${GCC_VERSION}"
  fi
  if [ -n "$GDB_VERSION" ]; then
    echo "::set-output name=GDB_VERSION::${GDB_VERSION}"
  fi
  if [ -n "$MAKE_VERSION" ]; then
    echo "::set-output name=MAKE_VERSION::${MAKE_VERSION}"
  fi
  echo "::set-output name=OUTPUT_BINARY::${NAME}.7z"
  echo "::set-output name=RELEASE_NAME::gcc-v${GCC_VERSION}"
fi
