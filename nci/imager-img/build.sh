#!/bin/sh -xe

wget http://weegie.edinburghlinux.co.uk/~neon/debs/live-build_20170920_all.deb
dpkg --install live-build_20170920_all.deb

lb clean --all
rm -rf config
./customize_pinebook
./flash_pinebook
