#!/bin/sh

git clone --depth 1 https://github.com/curl/curl.git &
git clone --depth 1 https://github.com/freetype/freetype.git &
git clone --depth 1 https://github.com/glennrp/libpng.git &
git clone --depth 1 https://github.com/libjpeg-turbo/libjpeg-turbo.git &
git clone --depth 1 https://github.com/zlib-ng/zlib-ng.git &
#git clone --depth 1 -b SDL2 https://github.com/libsdl-org/SDL.git &
wait
