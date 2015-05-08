#!/bin/sh

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8
SCRIPTDIR=$(readlink -f $(dirname -- "$0"))

echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' > /etc/apt/apt.conf.d/00cache
echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00aptitude
echo 'APT::Color "1";' > /etc/apt/apt.conf.d/99color

apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true install rake ruby ruby-dev build-essential

cd $SCRIPTDIR
exec rake -f deploy_in_container.rake deploy_in_container
