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
export METAPACKAGE=$5
export IMAGENAME=$6

if [ -z $WD ] || [ -z $DIST ] || [ -z $ARCH ] || [ -z $TYPE ] || [ -z $METAPACKAGE ] || [ -z $IMAGENAME ]; then
    echo "!!! Not all arguments provided! ABORT !!!"
    env
    exit 1
fi

cat /proc/self/cgroup

wget -qO - 'http://archive.neon.kde.org.uk/public.key' | sudo apt-key add -
sudo apt install -y software-properties-common
sudo apt-add-repository http://archive.neon.kde.org.uk/unstable
sudo apt update
sudo apt dist-upgrade -y
sudo apt install -y --no-install-recommends git ubuntu-defaults-builder wget ca-certificates zsync distro-info syslinux-utils livecd-rootfs

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

export CONFIG_HOOKS="$(dirname "$0")/config-hooks-${IMAGENAME}"
export BUILD_HOOKS="$(dirname "$0")/build-hooks-${IMAGENAME}"

# Preserve envrionment -E plz.
sudo -E $(dirname "$0")/ubuntu-defaults-image \
    --package $METAPACKAGE \
    --arch $ARCH \
    --release $DIST \
    --flavor neon \
    --components main,restricted,universe,multiverse

if [ ! -e livecd.neon.iso ]; then
    echo "ISO Build Failed."
    cleanup
    exit 1
fi

mv livecd.neon.* ../result/
cd ../result/

for f in *; do
    new_name=$(echo $f | sed "s/livecd\.neon/${IMAGENAME}-${DATE}-${ARCH}/")
    mv $f $new_name
done

zsyncmake *.iso

echo $DATETIME > date_stamp

pwd
chown -Rv jenkins:jenkins .

exit 0
