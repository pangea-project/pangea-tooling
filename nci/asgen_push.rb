#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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
require 'net/sftp'
require 'net/ssh'
require 'tmpdir'

require_relative '../ci-tooling/lib/debian/release'
require_relative '../ci-tooling/lib/nci'

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')

APTLY_REPOSITORY = ENV.fetch('APTLY_REPOSITORY')

run_dir = File.absolute_path('run')

# Move data into basic dir structure of repo skel.
export_dir = "#{run_dir}/export"
repo_dir = "#{export_dir}/repo"
dep11_dir = "#{repo_dir}/main/dep11"
FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
FileUtils.mkpath(dep11_dir)
FileUtils.cp_r("#{export_dir}/data/#{DIST}/main/.", dep11_dir, verbose: true)

# This depends on https://github.com/aptly-dev/aptly/pull/473
# Aptly versions must take care to actually have the PR applied to them until
# landed upstream!
# NB: this is updating off-by-one. i.e. when we run the old data is published,
#   we update the data but it will only be updated the next time the publish
#   is updated (we may do this in the future as acquire-by-hash is desired for
#   such quick update runs).

# We need the checksum of the uncompressed file in the Release file of the repo,
# this is currently not correctly handled in the aptly skel system. As a quick
# stop-gap we'll simply make sure an uncompressed file is around.
# https://github.com/aptly-dev/aptly/pull/473#issuecomment-391281324
Dir.glob("#{dep11_dir}/**/*.gz") do |compressed|
  system('gunzip', '-k', compressed) || raise
end

tmpdir = "/home/neonarchives/asgen_push.#{APTLY_REPOSITORY.tr('/', '-')}"
targetdir = "/home/neonarchives/aptly/skel/#{APTLY_REPOSITORY}/dists/#{DIST}"

Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives') do |sftp|
  puts sftp.session.exec!("rm -rf #{tmpdir}")
  puts sftp.session.exec!("mkdir -p #{tmpdir}")

  sftp.upload!("#{repo_dir}/", tmpdir)

  puts sftp.session.exec!("mkdir -p #{targetdir}/")
  puts sftp.session.exec!("cp -rv #{tmpdir}/. #{targetdir}/")
end
FileUtils.rm_rf(repo_dir)

pubdir = "/var/www/metadata/appstream/#{TYPE}_#{DIST}"
FileUtils.mkpath(pubdir)
FileUtils.cp_r("#{export_dir}/.", pubdir, verbose: true)
# This is the export dep11 data, we don't need it, so throw it away
FileUtils.rm_rf("#{export_dir}/data")
