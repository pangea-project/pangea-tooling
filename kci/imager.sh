#!/bin/sh -xe

JENKINS_PATH="/var/lib/jenkins"
TOOLING_PATH="$JENKINS_PATH/tooling"
CNAME="$DIST-jenkins-imager-$ARCH"

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

# cat /proc/self/cgroup || true
# cgm create all $CNAME || true
# cgm chown all $CNAME 100000 100000 || true
# cgm movepid all $CNAME $$ || true
# if ! cat /proc/self/cgroup | grep $CNAME; then
#     echo "cgroup setup failed!"
#     echo "aborting imager run as it would potentially compromise the session cgroup"
#     exit 1
# fi
# cgm removeonempty all $CNAME # this can now be fatal by default

# Manually handle the schroot session to prevent it from lingering after we exit.
export SCHROOT_SESSION="session:$(schroot -b -c $CNAME)"
# Creepy argument handling, but shell is shit
schroot -r -c $SCHROOT_SESSION $TOOLING_PATH/imager/build.sh `pwd` $DIST $ARCH $TYPE
schroot -e -c $SCHROOT_SESSION
unset SCHROOT_SESSION
echo $?
ls -lah result

DATE=$(cat result/date_stamp)
PUB=/var/www/kci/images/$ARCH/$DATE
mkdir -p $PUB
cp -r --no-preserve=ownership result/*.iso $PUB
cp -r --no-preserve=ownership result/*.manifest $PUB
cp -r --no-preserve=ownership result/*.zsync $PUB
ls -lah $PUB

chown jenkins:www-data -Rv $PUB

cp -avr $PUB /mnt/s3/kci/images/$ARCH/
