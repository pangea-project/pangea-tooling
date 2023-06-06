#!/bin/sh -xe

export WD=$1
export DIST=$2
export ARCH=$3
export TYPE=$4
export METAPACKAGE=$5
export IMAGENAME=$6
export NEONARCHIVE=$7

if [ -z $WD ] || [ -z $DIST ] || [ -z $ARCH ] || [ -z $TYPE ] || [ -z $METAPACKAGE ] || [ -z $IMAGENAME ] || [ -z $NEONARCHIVE ]; then
    echo "!!! Not all arguments provided! ABORT !!!"
    env
    exit 1
fi

_DATE=$(date +%Y%m%d)
_TIME=$(date +%H%M)
DATETIME="${_DATE}-${_TIME}"
REMIX_NAME="pinebook-remix"
export LIVE_IMAGE_NAME="${IMAGENAME}-${REMIX_NAME}-${TYPE}-${DATETIME}"

apt-get -y install qemu-user-static cpio parted udev zsync pigz live-build fdisk

lb clean --all
rm -rf config
mkdir -p chroot/usr/share/keyrings/
cp /usr/share/keyrings/ubuntu-archive-keyring.gpg chroot/usr/share/keyrings/ubuntu-archive-keyring.gpg
/tooling/nci/imager-img/configure_pinebook
lb build
# flash normal 768p build
/tooling/nci/imager-img/flash_pinebook ${LIVE_IMAGE_NAME}-${ARCH}.img

pigz --stdout ${LIVE_IMAGE_NAME}-${ARCH}.img > ${LIVE_IMAGE_NAME}-${ARCH}.img.gz
sha256sum ${LIVE_IMAGE_NAME}-${ARCH}.img.gz >> ${LIVE_IMAGE_NAME}-${ARCH}.sha256sum

# flash 1080p build and gzip it
/tooling/nci/imager-img/flash_pinebook_1080p ${LIVE_IMAGE_NAME}-${ARCH}.img
pigz --stdout ${LIVE_IMAGE_NAME}-${ARCH}.img > ${LIVE_IMAGE_NAME}-${ARCH}-1080p.img.gz
sha256sum ${LIVE_IMAGE_NAME}-${ARCH}-1080p.img.gz >> ${LIVE_IMAGE_NAME}-${ARCH}.sha256sum

echo $DATETIME > date_stamp
