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
# Ubuntu pushed a makedev update. We can't dist-upgrade makedev as it
# requires privileged access which we do not have on slaves. Hold it for 14
# days, after that unhold so the dist-upgrades fails again.
# At this point someone needs to determine if we want to wait longer or devise
# a solution. To fix this the ubuntu base image we use needs to be updated,
# which might happen soon. If not another approach is needed, extending this
# workaround is only reasonable for up to 2017-05-01 after that this needs
# a proper fix *at the latest*.
if [ "$(( (`date +%s` - `date +%s -d '2017/04/06'`) / 86400 ))" -ge "14" ]; then
  apt-mark hold makedev
else
  apt-mark unhold makedev
fi
apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true \
  dist-upgrade

cd $SCRIPTDIR
echo "Executing deploy_in_container.sh"
exec ./deploy_in_container.sh
