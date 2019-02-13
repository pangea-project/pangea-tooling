#!/bin/sh
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

# Deploys seeds onto HTTP server so they can be used by livecd-rootfs/germinate
# over HTTP.

# Of interest
# https://stackoverflow.com/questions/16351271/apache-redirects-based-on-symlinks

set -ex

ROOT=/srv/www/metadata.neon.kde.org/germinate
NEON_GIT="git://anongit.neon.kde.org"
UBUNTU_SEEDS="https://git.launchpad.net/~ubuntu-core-dev/ubuntu-seeds/+git"

dir="$ROOT/seeds.new.`date +%Y%m%d-%H%M%S`"
rm -rf $dir
mkdir -p $dir
cd $dir

git clone --depth 1 --branch Neon/unstable_xenial $NEON_GIT/neon/seeds neon.xenial
git clone --depth 1 --branch xenial $UBUNTU_SEEDS/platform platform.xenial

git clone --depth 1 --branch Neon/unstable $NEON_GIT/neon/seeds neon.bionic
git clone --depth 1 --branch xenial $UBUNTU_SEEDS/platform platform.bionic

cd $ROOT
old_dir=`readlink seeds` || true
rm -f seeds.new
ln -s $dir seeds.new
mv -T seeds.new seeds
rm -rf $old_dir
