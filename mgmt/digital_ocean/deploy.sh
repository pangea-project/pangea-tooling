#!/bin/bash
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

set -ex

# DOs by default come with out of date cache.
apt update

# Deploy chef 13 and chef-dk 1.3 (we have no ruby right now.)
cd /tmp
wget https://omnitruck.chef.io/install.sh
chmod +x install.sh
./install.sh -v 13
./install.sh -v 1.3 -P chefdk # so we can berks

# Use chef zero to cook localhost.
export NO_CUPBOARD=1
git clone --depth 1 https://github.com/blue-systems/pangea-kitchen.git /tmp/kitchen || true
cd /tmp/kitchen
git pull --rebase
berks install
berks vendor
chef-client --local-mode --enable-reporting

################################################### !!!!!!!!!!!
chmod 755 /root/deploy_tooling.sh
cp -v /root/deploy_tooling.sh /tmp/
sudo -u jenkins-slave -i /tmp/deploy_tooling.sh
################################################### !!!!!!!!!!!
