#!/bin/sh

set -e

# augment path to help it find cmake installed in /usr/local/bin,
# e.g. via brew. Xcode's Run Script phase doesn't seem to honor
# ~/.MacOSX/environment.plist
PATH="/usr/local/bin:$PATH"

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
export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig

cmake -DBUILD_SHARED_LIBS:BOOL=OFF \
    -DLIBSSH2_INCLUDE_DIRS:PATH=/usr/local/include/ \
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
