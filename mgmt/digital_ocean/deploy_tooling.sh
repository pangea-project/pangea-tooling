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

export PANGEA_UBUNTU_ONLY=1
# NOTE: the slave provisioning calls us with flattening disabled, by default
#   we should not be though. This script is also used for droplet image
#   maintenace, where we definitely want to flatten the image to compress the
#   droplet image and thus reduce bootstrapping and storage cost.
# export PANGEA_DOCKER_NO_FLATTEN=1

env

git clone --depth 1 https://github.com/blue-systems/pangea-tooling.git /tmp/tooling
cd /tmp/tooling

## from  mgmt_tooling_deploy.xml
rm -rv .bundle || true
gem install --no-rdoc bundler
bundle install --jobs=`nproc` --system --without development test

rake clean
rake deploy

find ~/tooling-pending/vendor/cache/* -maxdepth 0 -type d | xargs -r rm -rv

## from mgmt_docker more or less
# special hack, we force -jauto if this file is in the docker image
touch ~/tooling-pending/is_scaling_node
NODE_LABELS=amd64 mgmt/docker.rb
NODE_LABELS=amd64 mgmt/docker_cleanup.rb
