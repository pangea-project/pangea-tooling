#!/bin/sh -xe

JENKINS_PATH="/var/lib/jenkins"
TOOLING_PATH="$JENKINS_PATH/tooling"
CNAME="jenkins-imager-$DIST-$TYPE-$ARCH"

if ! schroot -i -c $CNAME; then
    echo "Imager schroot not set up. Talk to an admin."
    exit 1
fi

finish() {
    if [ ! -z $SCHROOT_SESSION ]; then
        schroot -e -c $SCHROOT_SESSION
        unset SCHROOT_SESSION
    fi
}
trap finish EXIT

# Manually handle the schroot session to prevent it from lingering after we exit.
export SCHROOT_SESSION="session:$(schroot -b -c $CNAME)"
# Creepy argument handling, but shell is shit

ssh jenkins@localhost "cd `pwd` && pwd && schroot -r -c $SCHROOT_SESSION $TOOLING_PATH/imager/build.sh `pwd` $DIST $ARCH $TYPE"
#schroot -r -c $SCHROOT_SESSION $TOOLING_PATH/imager/build.sh `pwd` $DIST $ARCH $TYPE

schroot -e -c $SCHROOT_SESSION

unset SCHROOT_SESSION

ls -lah result


DATE=$(cat result/date_stamp)
PUB=/var/www/kci/images/$ARCH/$DATE
mkdir -p $PUB
cp -r --no-preserve=ownership result/*.iso $PUB
cp -r --no-preserve=ownership result/*.manifest $PUB
cp -r --no-preserve=ownership result/*.zsync $PUB
chown jenkins:www-data -Rv $PUB

cp -avr $PUB /mnt/s3/kci/images/$ARCH/

~/jobs/mgmt_tooling/workspace/s3-images-generator/generate_html.rb -o /mnt/s3/kci/index.html kci

unset SCHROOT_SESSION
