#!/usr/bin/env ruby
# frozen_string_literal: true

# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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
require_relative '../lib/ci/container'
require_relative '../lib/ci/containment'
require 'deep_merge'

Docker.options[:read_timeout] = 2 * 60 * 60 # 2 hours

Dir.mkdir('app.Dir') unless Dir.exist?('app.Dir')
Dir.mkdir('source') unless Dir.exist?('source')
Dir.mkdir('appimages') unless Dir.exist?('appimages')

JOB_NAME = ENV.fetch('JOB_NAME')
IMAGE = ENV.fetch('DOCKER_IMAGE')

c = CI::Containment.new(
  JOB_NAME,
  image: IMAGE,
  privileged: true,
  binds: [
    Dir.pwd + ':/in',
    Dir.pwd + '/app.Dir:/app.Dir',
    Dir.pwd + '/appimages:/appimages',
    Dir.pwd + '/source:/source'
  ]
)
host_source = {
  Binds: [
    Dir.pwd + ':/in',
    Dir.pwd + '/app.Dir:/app.Dir',
    Dir.pwd + '/appimages:/appimages',
    Dir.pwd + '/source:/source'
  ],
  Devices: [
    {
      PathOnHost: '/dev/fuse',
      PathInContainer: '/dev/fuse',
      CgroupPermissions: 'mrw'
    }
  ],
  UsernsMode: 'host'
}

volume_source = {
  '/in' => {},
  '/source' => {},
  '/appimages' => {},
  '/app.Dir' => {},
  '/home/jenkins/.gnupg' => {},
  '/lib/modules' => {},
  '/tmp' => {}
}

status_code = c.run(
  Cmd: %w([bash -c /in/setup.sh]),
  HostConfig: host_source,
  Volumes: volume_source
)
exit status_code
