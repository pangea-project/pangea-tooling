#!/bin/bash

GIT="/usr/bin/git"

JENKINS_PATH="/var/lib/jenkins"
NETWORK_LOCK_PATH="$JENKINS_PATH/git-network-lock"

function sem_take {
    export SEM_DIR=""
    if [ ! -d $NETWORK_LOCK_PATH ]; then
        mkdir $NETWORK_LOCK_PATH
    fi
    echo "Waiting for git lock"
    while true; do
        pushd $NETWORK_LOCK_PATH
        {
            flock -x 200
            
            for i in $(seq 1 5); do
                if [ ! -d $i ]; then
                    mkdir $i
                    export SEM_DIR="$NETWORK_LOCK_PATH/$i"
                    break
                fi
            done
        } 200>$NETWORK_LOCK_PATH/_sem
        popd

        if [ "$SEM_DIR" != "" ]; then
            return 0
        fi

        sleep 5
    done
    echo "Acquired git lock"
}

function sem_release {
    if [ "$SEM_DIR" == "" ]; then
        return 0
    fi

    echo "Releasing git lock"
    {
        flock -x 200
        
        rmdir $SEM_DIR || true
        export SEM_DIR=""
    } 200>$NETWORK_LOCK_PATH/_sem
    echo "Released git lock"
}

# Heavily network bound functions are semaphored to establish a hard lock
# on how many connections we have to servers. This is a bit of a crude
# measure to prevent git.debian from crapping out because of jenkins
# timed triggers.
if [ "$1" = "pull" ] || [ "$1" = "clone" ] || [ "$1" = "fetch" ] || [ "$1" = "push" ]; then
    sem_take
    $GIT $@
    ret=$?
    sem_release
    exit $ret
fi

# # Git is sometimes having flaky connections to git.debian.org, so we are employing a
# # auto-retry method to make it less likely to fail.
# # The git command is retried 5 times before giving up.
# for i in $(seq 1 5); do
#     if ! $GIT $@; then
#         ret=$?
#         sleep 5
#     else
#         exit 0
#     fi
# done
# exit $ret
exec $GIT $@