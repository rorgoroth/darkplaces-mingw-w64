#!/bin/sh

rm Xonotic/*.exe
make -j8 release DP_MAKE_TARGET=mingw WIN64RELEASE=1
cp -v *.exe Xonotic/
