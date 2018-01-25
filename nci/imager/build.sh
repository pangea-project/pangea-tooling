#!/bin/sh

set -ex

cleanup() {
    if [ ! -d build ]; then
        mkdir build
    fi
    if [ ! -d result ]; then
        mkdir result
    fi
    rm -rf $WD/result/*
    rm -rf $WD/build/livecd.ubuntu.*
    rm -rf $WD/build/source.debian*
}

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

cat /proc/self/cgroup

# FIXME: let nci/lib/setup_repo.rb handle the repo setup as well this is just
# duplicate code here...
ls -lah /tooling/nci
ls -lah /tooling/ci-tooling
ls -lah /tooling/ci-tooling/lib
/tooling/nci/setup_apt_repo.rb --no-repo
sudo apt-add-repository http://archive.neon.kde.org/${NEONARCHIVE}
sudo apt update
sudo apt dist-upgrade -y
sudo apt install -y --no-install-recommends \
    git ubuntu-defaults-builder wget ca-certificates zsync distro-info \
    syslinux-utils livecd-rootfs xorriso pxz

rm /usr/bin/xz
ln -s /usr/bin/pxz /usr/bin/xz
cat << EOF > /usr/bin/xz.0
/usr/bin/pxz -0 "\$0"
EOF
chmod +x /usr/bin/xz.0
ls -lah /usr/bin/xz.0

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
sudo apt install -y --no-install-recommends  syslinux-themes-ubuntu syslinux-themes-neon
# sudo ln -s /usr/lib/syslinux/modules/bios/ldlinux.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/ldlinux.c32
# sudo ln -s /usr/lib/syslinux/modules/bios/libutil.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/libutil.c32
# sudo ln -s /usr/lib/syslinux/modules/bios/libcom32.c32 /usr/share/syslinux/themes/ubuntu-$DIST/isolinux-live/libcom32.c32

# # Compress with XZ, because it is awesome!
# JOB_COUNT=2
# export MKSQUASHFS_OPTIONS="-comp xz -processors $JOB_COUNT"

# Since we can not define live-build options directly, let's cheat our way
# around defaults-image by exporting the vars lb uses :O

## Super internal var used in lb_binary_disk to figure out the version of LB_DISTRIBUTION
EDITION=$(echo $NEONARCHIVE | sed 's,/,,')
export RELEASE_${DIST}=${EDITION}
## Bring down the overall size a bit by using a more sophisticated albeit expensive algorithm.
export LB_COMPRESSION=xz
## Create a zsync file allowing over-http delta-downloads.
export LB_ZSYNC=true # This is overridden by silly old defaults-image...
## Use our cache as proxy.
# FIXME: get out of nci/lib/setup_repo.rb
export LB_APT_HTTP_PROXY="http://apt.cache.pangea.pub:8000"

## Reduce compression level from default (-6) to (-0). -0 is often smaller than
## gz but much faster than -6. It may well be that this is also increases
## squashfs size, so we may not want this in production actually.
## Ideally this should only apply for source tarball.
export XZ_OPT=-0

export CONFIG_SETTINGS="$(dirname "$0")/config-settings-${IMAGENAME}.sh"
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
mv source.debian.tar.xz ../result/ || true
cd ../result/

for f in live*; do
    new_name=$(echo $f | sed "s/livecd\.neon/${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}/")
    mv $f $new_name
done

mv source.debian.tar.xz ${IMAGENAME}-${TYPE}-${DATETIME}-source.tar.xz || true
ln -s ${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.iso ${IMAGENAME}-${TYPE}-current.iso
zsyncmake ${IMAGENAME}-${TYPE}-current.iso
sha256sum ${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.iso > ${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.sha256sum
cat > .message << END
KDE neon

${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.iso Live and Installable ISO
${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.iso.sig PGP Digital Signature
${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.manifest ISO contents
${IMAGENAME}-${TYPE}-${DATETIME}-${ARCH}.sha256sum Checksum
"current" files are the same files for those wanting a URL which does not change daily.
END
echo $DATETIME > date_stamp

pwd
chown -Rv jenkins:jenkins .

exit 0
