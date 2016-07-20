#!/bin/sh

set -ex

SCRIPTDIR=$(readlink -f $(dirname -- "$0"))

export DEBIAN_FRONTEND=noninteractive
export LANG=en_US.UTF-8

echo "LANG=$LANG" >> /etc/profile
echo "LANG=$LANG" >> /etc/environment

# FIXME: reneable
# echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' > /etc/apt/apt.conf.d/00cache
echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/00aptitude
echo 'APT::Color "1";' > /etc/apt/apt.conf.d/99color

# Switch to cloudfront for debian
sed -i 's,httpredir.debian.org,deb.debian.org,g' /etc/apt/sources.list
sed -i 's,ftp.debian.org,deb.debian.org,g' /etc/apt/sources.list

i="3"
while [ $i -gt 0 ]; do
  apt-get update && break
  i=$((i-1))
  sleep 60 # sleep a bit to give problem a chance to resolve
done

ESSENTIAL_PACKAGES="rake ruby ruby-dev build-essential zlib1g-dev git-core"
i="5"
while [ $i -gt 0 ]; do
  apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true \
    install ${ESSENTIAL_PACKAGES} && break
  i=$((i-1))
done


# Make sure our ruby version is atleast 2.2
ruby_major_version=$(ruby -e "puts \"#{RbConfig::CONFIG['MAJOR']}\"")
ruby_minor_version=$(ruby -e "puts \"#{RbConfig::CONFIG['MINOR']}\"")

if [ $ruby_minor_version -lt 2 ] && [ $ruby_major_version -le 2 ]; then
  echo "Ruby Version ${ruby_major_version}.${ruby_minor_version}"
  echo "Compiling our own ruby!"
  apt-get -y -o APT::Get::force-yes=true -o Debug::pkgProblemResolver=true \
    install ruby-build curl
  curl -s https://raw.githubusercontent.com/rbenv/ruby-build/master/share/ruby-build/2.3.1 &> /tmp/2.3.1
  ruby-build /tmp/2.3.1 /usr/local
fi

cd $SCRIPTDIR
exec rake -f deploy_in_container.rake deploy_in_container
