#!/bin/bash

# http://wiki.openwrt.org/doc/howto/build

./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
make defconfig
make V=s 2>&1 | tee build.log

