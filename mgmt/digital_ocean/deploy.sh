#!/bin/bash
# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

set -ex

# Don't query us about things. We can't answer.
export DEBIAN_FRONTEND=noninteractive

# Disable bloody apt automation crap locking the database.
systemctl disable --now apt-daily.timer
systemctl disable --now apt-daily.service
systemctl mask apt-daily.service
systemctl mask apt-daily.timer
systemctl stop apt-daily.service || true

systemctl disable --now apt-daily-upgrade.timer
systemctl disable --now apt-daily-upgrade.service
systemctl mask apt-daily-upgrade.timer
systemctl mask apt-daily-upgrade.service
systemctl stop apt-daily-upgrade.service || true

# SSH comes up while cloud-init is still in progress. Wait for it to actually
# finish.
until grep '"stage"' /run/cloud-init/status.json | grep -q 'null'; do
  echo "waiting for cloud-init to finish"
  sleep 4
done

# Make sure we do not have random services claiming dpkg locks.
# Nor random background stuff we don't use (snapd, lxd)
# Nor automatic cron jobs. Cloud servers aren't remotely long enough around for
# cron jobs to matter.
ps aux
apt purge -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
  -y unattended-upgrades update-notifier-common snapd lxd cron

# DOs by default come with out of date cache.
ps aux
apt update

# Make sure the image is up to date.
apt dist-upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Deploy chef 15 (we have no ruby right now.)
cd /tmp
wget https://omnitruck.chef.io/install.sh
chmod +x install.sh
./install.sh -v 15
./install.sh -v 23 -P chef-workstation # so we can berks

# Use chef zero to cook localhost.
export NO_CUPBOARD=1
git clone --depth 1 https://github.com/pangea-project/pangea-kitchen.git /tmp/kitchen || true
cd /tmp/kitchen
git pull --rebase
berks install
berks vendor
chef-client --local-mode --enable-reporting --chef-license accept-silent

# Make sure we do not have random services claiming dpkg locks.
apt purge -y unattended-upgrades

################################################### !!!!!!!!!!!
chmod 755 /root/deploy_tooling.sh
cp -v /root/deploy_tooling.sh /tmp/
sudo -u jenkins-slave -i /tmp/deploy_tooling.sh
################################################### !!!!!!!!!!!

# Clean up cache to reduce image size.
# We don't need to keep chef. It's only in this deployment script and it
# only runs daily, so speed is not of the essence nor does it help anything.
# We can easily install chef again on the next run, it costs nothing but reduces
# the image size by a non trivial amount.
apt-get -y purge chef\*
apt --purge --yes autoremove
apt-get clean
# We could skip docs via dpkg exclusion rules like used in the ubuntu docker
# image but it's hardly worth the headache here. The overhead of installing
# them and then removing them again hardly makes any diff.
rm -rfv /usr/share/ri/*
rm -rfv /usr/share/doc/*
rm -rfv /usr/share/man/*
journalctl --vacuum-time=1s
rm -rfv /var/log/journal/*
truncate -s 0 \
  /var/log/fail2ban.log \
  /var/log/cloud-init.log \
  /var/log/syslog \
  /var/log/kern.log \
  /var/log/apt/term.log \
  || true
