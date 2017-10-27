#!/bin/sh

# Distribution Upgrader.
# This deployer upgrades the base image distribution. It is used so we can
# go from 16.04 to 16.10 even before docker has proper 16.10 images. This is
# achieved by simply subbing the sources.list around and doing a dist-upgrade.

set -ex

if [ -z "$1" ]; then
  echo "$0 called with no argument from where to transition from (argument 1)"
  exit 1
fi
if [ -z "$2" ]; then
  echo "$0 called with no argument from where to transition to (argument 2)"
  exit 1
fi

SCRIPTDIR=$(readlink -f $(dirname -- "$0"))

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

sed -i "s/$1/$2/g" /etc/apt/sources.list
sed -i "s/$1/$2/g" /etc/apt/sources.list.d/* || true

apt-get update
apt-mark hold makedev # do not update makedev it won't work on unpriv'd
apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true \
  dist-upgrade

cd $SCRIPTDIR
echo "Executing deploy_in_container.sh"
exec ./deploy_in_container.sh
