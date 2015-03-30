#!/bin/bash

# unset rvm variables because lxc-attach doesn't drop the host env
unset GEM_PATH
unset GEM_HOME
unset IRBRC
unset MY_RUBY_HOME
unset RUBY_VERSION

export CNAME=${JOB_NAME##*/}

JENKINS_PATH="/var/lib/jenkins"
# FIXME: builder needs gnupg which is outside confined
# FIXME: confined should be read-only in the container
TOOLING_PATH="$JENKINS_PATH/tooling/confined"
TIMEOUT=120 # At peak we have severe load, so better use a sizable timeout for lxc startup...
START_RETRIES=8

if [ -z $DIST ] || [ -z $TYPE ] || [ -z $JOB_NAME ]; then
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

lxc-stop -n $CNAME || true
lxc-wait -n $CNAME --state=STOPPED --timeout=$TIMEOUT
lxc-destroy -n $CNAME || true

lxc-clone -s -B overlayfs "${DIST}_${TYPE}" $CNAME

# Mount tooling and workspace directory.
echo "lxc.mount.entry = ${TOOLING_PATH} ${TOOLING_PATH#/} none ro,bind,create=dir" >> $JENKINS_PATH/.local/share/lxc/$CNAME/config
echo "lxc.mount.entry = ${PWD} ${PWD#/} none bind,create=dir" >> $JENKINS_PATH/.local/share/lxc/$CNAME/config

started=1
for i in $(seq 1 $START_RETRIES); do
  lxc-start -n $CNAME --daemon --logfile=`pwd`/lxc.log --logpriority=INFO
  if [ $? -eq 0 ]; then
    started=0
    break
  fi
done
if [ $started -ne 0 ]; then
  echo "Failed to start container"
  exit 1
fi

lxc-wait -n $CNAME --state=RUNNING --timeout=$TIMEOUT || exit 1

# Running has no correlation with network-up. Make sure the container
# got an IP address before trying to do anything with it.
# Builds will require additional software or network access in other ways.
for i in $(seq 1 $TIMEOUT); do
    if [ -n "$(lxc-info --no-humanize --ips -n $CNAME)" ]; then
        HAS_IP=true
        break
    fi
    sleep 5
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
lxc-attach -n $CNAME $@
