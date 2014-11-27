#!/bin/bash

# http://wiki.openwrt.org/doc/howto/build
rm -f build.log
date >> build.log
make dirclean
./scripts/feeds update -a
./scripts/feeds install -a
make menuconfig
make V=s 2>&1 | tee -a build.log
date >> build.log

