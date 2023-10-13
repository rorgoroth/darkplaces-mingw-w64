#!/bin/sh

# NOTE: This is specific to my set-up.

export CC=x86_64-w64-mingw32-gcc
export CXX=x86_64-w64-mingw32-g++
export PATH="/mingw64/bin:$PATH"
export PKG_CONFIG="pkg-config --static"
export PKG_CONFIG_LIBDIR="/mingw64/mingw/lib/pkgconfig"
export CFLAGS="-march=x86-64-v3 -O3 -flto=thin -fdata-sections -ffunction-sections -fvisibility=hidden"
export CXXFLAGS="-march=x86-64-v3 -O3 -flto=thin -fdata-sections -ffunction-sections -fvisibility=hidden"
export LDFLAGS="-flto=thin -Wl,--gc-sections -Wl,--icf=all"

cd curl && git reset --hard origin/master && git clean -xdf && git pull
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/mingw64/mingw -DCMAKE_TOOLCHAIN_FILE=~/mingw/build/toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_CURL_EXE=OFF -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DCURL_BROTLI=OFF -DCURL_ENABLE_SSL=ON -DCURL_LTO=OFF -DCURL_STATIC_CRT=OFF -DCURL_TARGET_WINDOWS_VERSION=0x0A00 -DCURL_USE_SCHANNEL=ON -DCURL_WERROR=OFF -DCURL_WINDOWS_SSPI=ON -DCURL_ZLIB=ON -DCURL_ZSTD=ON -DENABLE_ARES=OFF -DENABLE_CURLDEBUG=OFF -DENABLE_DEBUG=OFF -DENABLE_INET_PTON=ON -DENABLE_THREADED_RESOLVER=ON -DENABLE_UNICODE=ON -DENABLE_UNIX_SOCKETS=ON -DPICKY_COMPILER=ON -DUSE_LIBIDN2=ON -DUSE_MSH3=OFF -DUSE_NGHTTP2=OFF -DUSE_NGTCP2=OFF -DUSE_QUICHE=OFF -DUSE_WIN32_IDN=OFF -DUSE_WIN32_LDAP=ON .
    ninja
    cp -v lib/libcurl.dll ../../Xonotic/bin64/libcurl-4.dll || exit
cd ..

cd freetype && git reset --hard origin/master && git clean -xdf && git pull
    meson setup build --prefix=/mingw64/mingw --libdir=/mingw64/mingw/lib --cross-file=~/mingw/build/meson_cross.txt --buildtype=release --default-library=shared -Dbzip2=enabled -Dharfbuzz=disabled -Dmmap=enabled -Dpng=enabled -Dbrotli=disabled -Dtests=disabled -Dzlib=system
    ninja -C build
    cp -v build/libfreetype-6.dll ../../Xonotic/bin64
cd ..

cd libjpeg-turbo && git reset --hard origin/main && git clean -xdf && git pull
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/mingw64/mingw -DCMAKE_TOOLCHAIN_FILE=~/mingw/build/toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHARED=ON -DENABLE_STATIC=OFF
    ninja
    cp -v libjpeg-62.dll ../../Xonotic/bin64 || exit
cd ..

cd libpng && git reset --hard origin/libpng16 && git clean -xdf && git pull
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/mingw64/mingw -DCMAKE_TOOLCHAIN_FILE=~/mingw/build/toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DPNG_BUILD_ZLIB=OFF -DPNG_DEBUG=OFF -DPNG_EXECUTABLES=OFF -DPNG_FRAMEWORK=OFF -DPNG_HARDWARE_OPTIMIZATIONS=ON -DPNG_INTEL_SSE=on -DPNG_SHARED=ON -DPNG_STATIC=OFF -DPNG_TESTS=OFF -Dld-version-script=ON
    ninja
    cp -v libpng16.dll ../../Xonotic/bin64 || exit
cd ..

#cd SDL && git reset --hard origin/SDL2 && git clean -xdf && git pull
#    cmake -G Ninja -B build -DCMAKE_INSTALL_PREFIX=/mingw64/mingw -DCMAKE_TOOLCHAIN_FILE=~/mingw/build/toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DSDL_HAPTIC=OFF -DSDL_JOYSTICK=OFF -DSDL_XINPUT=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF -DSDL_THREADS=ON -DSDL_VULKAN=ON
#    ninja -C build
#    cp -v build/SDL2.dll ../../Xonotic/ || exit
#cd ..

cd zlib-ng && git reset --hard origin/develop && git clean -xdf && git pull
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX=/mingw64/mingw -DCMAKE_TOOLCHAIN_FILE=~/mingw/build/toolchain.cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_GMOCK=OFF -DFETCHCONTENT_FULLY_DISCONNECTE=ON -DFETCHCONTENT_QUIET=OFF -DINSTALL_GTEST=OFF -DWITH_AVX512=ON -DWITH_AVX512VNNI=OFF -DWITH_BENCHMARK_APPS=OFF -DWITH_BENCHMARKS=OFF -DWITH_CODE_COVERAGE=OFF -DWITH_FUZZERS=OFF -DWITH_GTEST=OFF -DWITH_GZFILEOP=ON -DWITH_MAINTAINER_WARNINGS=OFF -DWITH_NATIVE_INSTRUCTIONS=OFF -DWITH_NEW_STRATEGIES=ON -DWITH_OPTIM=ON -DWITH_SANITIZER=AUTO -DWITH_VPCLMULQDQ=OFF -DZLIB_COMPAT=ON -DZLIB_ENABLE_TESTS=OFF -DZLIBNG_ENABLE_TESTS=OFF
    ninja
    cp -v libzlib1.dll ../../Xonotic/bin64/zlib1.dll || exit
cd ..
