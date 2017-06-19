#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Jonathan Riddell <jr@jriddell.org>
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

require 'fileutils'

require_relative '../lib/ci/containment'

TOOLING_PATH = File.dirname(__dir__)

JOB_NAME = ENV.fetch('JOB_NAME')
DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
METAPACKAGE = ENV.fetch('METAPACKAGE')
IMAGENAME = ENV.fetch('IMAGENAME')
NEONARCHIVE = ENV.fetch('NEONARCHIVE')

Docker.options[:read_timeout] = 4 * 60 * 60 # 4 hours.

binds = [
  TOOLING_PATH,
  Dir.pwd
]

c = CI::Containment.new(JOB_NAME,
                        image: CI::PangeaImage.new(:ubuntu, DIST),
                        binds: binds,
                        privileged: true,
                        no_exit_handlers: false)
cmd = ["#{TOOLING_PATH}/nci/imager/build.sh",
       Dir.pwd, DIST, ARCH, TYPE, METAPACKAGE, IMAGENAME, NEONARCHIVE]
status_code = c.run(Cmd: cmd)

# Write a params file we can use to pass our relevant information to a child
# build for additional processing.
File.write('params.txt', <<-EOF)
ISO=#{File.realpath(Dir.glob('*.iso').fetch(0))}
EOF

exit status_code unless status_code.to_i.zero?
