#!/bin/sh -xe

cleanup() {
    if [ ! -d build ]; then
        mkdir build
    fi
    if [ ! -d result ]; then
        mkdir result
    fi
    rm -rf $WD/result/*
    rm -rf $WD/build/livecd.ubuntu.*
}

export WD=$1
export DIST=$2
export ARCH=$3
export TYPE=$4

if [ -z $WD ] || [ -z $DIST ] || [ -z $ARCH ] || [ -z $TYPE ]; then
    echo "!!! Not all arguments provided! ABORT !!!"
    env
    exit 1
fi

cat /proc/self/cgroup

sudo apt update
sudo apt dist-upgrade -y
sudo apt install -y --no-install-recommends git ubuntu-defaults-builder wget ca-certificates zsync distro-info syslinux-utils

# NOTE: can be removed once ubuntu-defaults-image and live-build landed in utopic-updates.
# FIXME: source schroot needs to be updated with updates enabled, or at least the two core packages updated.
sudo apt install -y --no-install-recommends software-properties-common
sudo apt-add-repository -y "deb http://127.0.0.1:3142/archive.ubuntu.com/ubuntu $DIST-updates main restricted universe multiverse"
sudo apt update
sudo apt dist-upgrade -y


cd $WD
ls -lah
cleanup
ls -lah

cd $WD/build

_DATE=$(date +%Y%m%d)
_TIME=$(date +%H%M)
DATETIME="${_DATE}-${_TIME}"
DATE="${_DATE}${_TIME}"

# Random nonesense sponsored by Rohan.
# Somewhere in utopic things fell to shit, so lb doesn't pack all files necessary
# for isolinux on the ISO. Why it happens or how or what is unknown. However linking
# the required files into place seems to solve the problem. LOL.
sudo apt install -y --no-install-recommends  syslinux-themes-ubuntu
# sudo ln -s /usr/lib/syslinux/modules/bios/ldlinux.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/ldlinux.c32
# sudo ln -s /usr/lib/syslinux/modules/bios/libutil.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/libutil.c32
# sudo ln -s /usr/lib/syslinux/modules/bios/libcom32.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/libcom32.c32

# # Compress with XZ, because it is awesome!
# JOB_COUNT=2
# export MKSQUASHFS_OPTIONS="-comp xz -processors $JOB_COUNT"

# Since we can not define live-build options directly, let's cheat our way
# around defaults-image by exporting the vars lb uses :O

## Super internal var used in lb_binary_disk to figure out the version of LB_DISTRIBUTION
export RELEASE_${DIST}=$(distro-info --series=$DIST -r)
## Bring down the overall size a bit by using a more sophisticated albeit expensive algorithm.
export LB_COMPRESSION=xz
## Create a zsync file allowing over-http delta-downloads.
export LB_ZSYNC=true # This is overridden by silly old defaults-image...
## Proxy the chroot (including PPAs) through apt-cacher to reduce network-bound I/O.
export LB_APT_HTTP_PROXY="http://127.0.0.1:3142"

# Preserve envrionment -E plz.
sudo -E $(dirname "$0")/ubuntu-defaults-image \
    --ppa kubuntu-ci/$TYPE-daily \
    --package kubuntu-ci-live \
    --arch $ARCH \
    --release $DIST \
    --flavor kubuntu \
    --mirror http://127.0.0.1:3142/archive.ubuntu.com/ubuntu \
    --components main,restricted,universe,multiverse

if [ ! -e livecd.kubuntu.iso ]; then
    echo "ISO Build Failed."
    cleanup
    exit 1
fi

mv livecd.kubuntu.* ../result/
cd ../result/

for f in *; do
    new_name=$(echo $f | sed "s/livecd\.kubuntu/kubuntu-${DATE}-${ARCH}/")
    mv $f $new_name
done

zsyncmake *.iso

echo $DATETIME > date_stamp

exit 0
