#!/bin/sh

cd /

echo 'jenkins ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
echo 'Acquire::http { Proxy "http://10.0.3.1:3142"; };' > /etc/apt/apt.conf.d/apt-cacher

apt-get update
apt-get dist-upgrade
apt-get install -y git ubuntu-defaults-builder wget ca-certificates --no-install-recommends
