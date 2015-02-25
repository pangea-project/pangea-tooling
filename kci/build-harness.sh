#!/bin/bash

set -ex

# unset rvm variables because lxc-attach doesn't drop the host env
unset GEM_PATH
unset GEM_HOME
unset IRBRC
unset MY_RUBY_HOME
unset RUBY_VERSION

export CNAME=${JOB_NAME##*/}

JENKINS_PATH="/var/lib/jenkins"
TOOLING_PATH="$JENKINS_PATH/tooling"
TIMEOUT=120 # At peak we have severe load, so better use a sizable timeout for lxc startup...

if [ -z $DIST ] || [ -z $NAME ] || [ -z $TYPE ] || [ -z $JOB_NAME ]; then
    echo "Not all env variables set! ABORT!"
    exit 1
fi

function finish {
    # Let's not fail here since it does not contribute to overall build status
    lxc-stop -n $CNAME || true
    lxc-wait -n $CNAME --state=STOPPED --timeout=30 || true
    lxc-destroy -n $CNAME || true
}
trap finish EXIT

rm -rf _anchor-chain logs/* build/*

lxc-stop -n $CNAME || true
lxc-wait -n $CNAME --state=STOPPED --timeout=$TIMEOUT
lxc-destroy -n $CNAME || true
#lxc-start-ephemeral -o $DIST_$TYPE -n $NAME --bdir $JENKINS_PATH/ -d
lxc-clone -s -B overlayfs "${DIST}_${TYPE}" $CNAME
# Mount tooling and workspace directory.
echo "lxc.mount.entry = ${TOOLING_PATH} ${TOOLING_PATH#/} none bind,create=dir" >> $JENKINS_PATH/.local/share/lxc/$CNAME/config
echo "lxc.mount.entry = ${PWD} ${PWD#/} none bind,create=dir" >> $JENKINS_PATH/.local/share/lxc/$CNAME/config
cat /proc/uptime
lxc-start -n $CNAME --daemon --logfile=`pwd`/lxc.log --logpriority=INFO
lxc-wait -n $CNAME --state=RUNNING --timeout=$TIMEOUT
# Running has no correlation with network-up. Make sure the container
# got an IP address before trying to do anything with it.
# Builds will require additional software or network access in other ways.
for i in $(seq 1 $TIMEOUT); do
    if [ -n "$(lxc-info --no-humanize --ips -n $CNAME)" ]; then
        HAS_IP=true
        break
    fi
    sleep 1
done
cat /proc/uptime
if [ ! $HAS_IP ]; then
    lxc-info --no-humanize --ips -n $CNAME
    free -h
    lxc-info -n $CNAME
    brctl show lxcbr0
    echo "For some reason the container did not get an IP address. Aborting..."
    exit 1
fi
lxc-ls -f
lxc-attach -n $CNAME $TOOLING_PATH/builder.rb ${JOB_NAME##*/} `pwd`

if [ "$DIST" == "vivid" ]; then
    cd packaging
    git push packaging HEAD:kubuntu_unstable || true
fi

/var/lib/jenkins/tooling3/ci-tooling/kci/ppa-copy-package.rb
