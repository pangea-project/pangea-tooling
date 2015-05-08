#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8
SCRIPTDIR=$(readlink -f $(dirname -- "$0"))

apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true install rake ruby ruby-dev build-essential

cd $SCRIPTDIR
exec rake -f deploy_in_container.rake deploy_in_container
