#!/bin/sh -xe

wget http://weegie.edinburghlinux.co.uk/~neon/debs/live-build_20170920_all.deb
dpkg --install live-build_20170920_all.deb
apt-get -y install qemu-user-static # for arm emulation

lb clean --all
rm -rf config
mkdir -p chroot/usr/share/keyrings/
cp /usr/share/keyrings/ubuntu-archive-keyring.gpg chroot/usr/share/keyrings/ubuntu-archive-keyring.gpg
/tooling/nci/imager-img/configure_pinebook
lb build --debug
/tooling/nci/imager-img/flash_pinebook
