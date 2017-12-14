#!/bin/sh -xe

wget http://weegie.edinburghlinux.co.uk/~neon/debs/live-build_20170920_all.deb
dpkg --install live-build_20170920_all.deb
apt-get -y install qemu-user-static # for arm emulation

lb clean --all
rm -rf config
/tooling/nci/imager-img/configure_pinebook
lb build
/tooling/nci/imager-img/flash_pinebook
