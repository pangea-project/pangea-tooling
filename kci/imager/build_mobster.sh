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

cd $WD
cleanup

cd $WD/build

_DATE=$(date +%Y%m%d)
_TIME=$(date +%H%M)
DATETIME="${_DATE}-${_TIME}"
DATE="${_DATE}${_TIME}"

sudo apt install -y --no-install-recommends  syslinux-themes-ubuntu

# Since we can not define live-build options directly, let's cheat our way
# around defaults-image by exporting the vars lb uses :O

## Super internal var used in lb_binary_disk to figure out the version of LB_DISTRIBUTION
export RELEASE_${DIST}=$(distro-info --series=$DIST -r)
## Bring down the overall size a bit by using a more sophisticated albeit expensive algorithm.
export LB_COMPRESSION=xz
## Create a zsync file allowing over-http delta-downloads
export LB_ZSYNC=true # This is overridden by silly old defaults-image...

export CONFIG_HOOKS="$(dirname "$0")/mobster-config-hooks"
export BUILD_HOOKS="$(dirname "$0")/mobster-hooks"

# Preserve envrionment -E plz.
sudo -E $(dirname "$0")/ubuntu-defaults-image \
    --ppa plasma-phone/ppa \
    --package upstart \
    --arch $ARCH \
    --release $DIST \
    --flavor kubuntu \
    --components main,restricted,universe,multiverse

if [ ! -e livecd.kubuntu.iso ]; then
    echo "ISO Build Failed."
    cleanup
    exit 1
fi

mv livecd.kubuntu.* ../result/
cd ../result/

for f in *; do
    new_name=$(echo $f | sed "s/livecd\.kubuntu/kubuntu-pm_${DATE}-${ARCH}/")
    mv $f $new_name
done

zsyncmake *.iso

echo $DATETIME > date_stamp

chown -R jenkins:jenkins .

exit 0
