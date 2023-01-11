#!/bin/sh

set -e

if [ -z "$ARCHS" ]; then
  ARCHS=$(uname -m)
fi

# augment path to help it find cmake installed e.g. via brew.
# Xcode's Run Script phase doesn't seem to honor
# ~/.MacOSX/environment.plist
if [[ $ARCHS == 'arm64' ]]; then
  HOMEBREW_ROOT="/opt/homebrew"
  OPENSSL_DIR="openssl"
else
  HOMEBREW_ROOT="/usr/local"
  OPENSSL_DIR="openssl@3"
fi
PATH="${HOMEBREW_ROOT}/bin:$PATH"

if [ "libgit2-mac.a" -nt "libgit2" ]
then
    echo "No update needed."
    exit 0
fi

cd "libgit2"

if [ -d "build" ]; then
    rm -rf "build"
fi

mkdir build
cd build

# OpenSSL is keg-only, so add its pkgconfig location manually
export PKG_CONFIG_PATH="${HOMEBREW_ROOT}/opt/${OPENSSL_DIR}/lib/pkgconfig"

cmake -DBUILD_SHARED_LIBS:BOOL=OFF \
    -DLIBSSH2_INCLUDE_DIRS:PATH=${HOMEBREW_ROOT}/include/ \
    -DBUILD_CLAR:BOOL=OFF \
    -DTHREADSAFE:BOOL=ON \
    ..
cmake --build .

product="libgit2.a"
install_path="../../"
if [ "libgit2.a" -nt "${install_path}/libgit2-mac.a" ]; then
    cp -v "libgit2.a" "${install_path}/libgit2-mac.a"
fi

echo "libgit2 has been updated."
