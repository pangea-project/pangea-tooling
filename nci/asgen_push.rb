#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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

require 'net/sftp'
require 'net/ssh'

repodir = File.absolute_path('run/export/repo')
tmpdir = '/home/nci/asgen_push'
targetdir = '/home/nci/aptly/public/release/dists/xenial'

Net::SSH.start('localhost', 'nci') do |ssh|
  puts ssh.exec!("rm -rf #{tmpdir}")
  puts ssh.exec!("mkdir -p #{tmpdir}")
  puts ssh.exec!("cp -rv #{repodir}/. #{tmpdir}")
  puts ssh.exec!("gpg --digest-algo SHA256 --armor -s -o #{tmpdir}/InRelease --clearsign #{tmpdir}/Release")
  puts ssh.exec!("gpg --digest-algo SHA256 --armor --detach-sign -s -o #{tmpdir}/Release.gpg  #{tmpdir}/Release")
  puts ssh.exec!("cp -rv #{tmpdir}/. #{targetdir}/")
end
