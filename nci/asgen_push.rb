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
require 'tty-command'

require_relative '../ci-tooling/lib/debian/release'
require_relative '../ci-tooling/lib/nci'

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
APTLY_REPOSITORY = ENV.fetch('APTLY_REPOSITORY')

run_dir = File.absolute_path('run')

# Move data into basic dir structure of repo skel.
export_dir = "#{run_dir}/export"
export_data_dir = "#{export_dir}/data"
repo_dir = "#{export_dir}/repo"
dep11_dir = "#{repo_dir}/main/dep11"

unless File.exist?(export_data_dir)
  warn "The data dir #{export_data_dir} does not exist." \
       ' It seems asgen found no new data. Skipping publish!'
  exit 0
end

FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
FileUtils.mkpath(dep11_dir)
FileUtils.cp_r("#{export_data_dir}/#{DIST}/main/.", dep11_dir, verbose: true)

tmpdir = "/home/neonarchives/asgen_push.#{APTLY_REPOSITORY.tr('/', '-')}"
targetdir = "/home/neonarchives/aptly/skel/#{APTLY_REPOSITORY}/dists/#{DIST}"

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
  next if compressed.include?('by-hash') # do not follow by-hash
  system('gunzip', '-k', compressed) || raise
end

Sum = Struct.new(:file, :value)

keys_and_tools = {
  'MD5Sum' => 'md5sum',
  'SHA1' => 'sha1sum',
  'SHA256' => 'sha256sum',
  'SHA512' => 'sha512sum'
}

keys_and_sums = {}

cmd = TTY::Command.new

# Create a sum map for all files, we'll then by-hash each of them.
Dir.glob("#{dep11_dir}/*") do |file|
  next if File.basename(file) == 'by-hash'
  raise "Did not expect !file: #{file}" unless File.file?(file)
  keys_and_tools.each do |key, tool|
    keys_and_sums[key] ||= []
    sum = cmd.run(tool, file).out.split(' ')[0]
    keys_and_sums[key] << Sum.new(File.absolute_path(file), sum)
  end
end
require 'pp'
pp keys_and_sums

Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives',
                keys: ENV.fetch('SSH_KEY_FILE'), keys_only: true) do |sftp|
  begin
    sftp.lstat!("#{targetdir}/by-hash")
    sftp.download!("#{targetdir}/by-hash", dep11_dir)
  rescue Net::SFTP::StatusException
    warn 'by-hash does not exist yet! generating from scratch'
  end
end

keys_and_sums.each do |key, sums|
  dir = "#{dep11_dir}/by-hash/#{key}/"
  FileUtils.mkpath(dir) unless File.exist?(dir)
  Dir.chdir(dir) do
    sums.each do |sum|
      basename = File.basename(sum.file)

      rotate = proc do
        old = "#{basename}.old"
        if File.exist?(old)
          link_target = File.readlink(old)
          FileUtils.rm_f([link_target, old], verbose: true)
        end
        FileUtils.mv(basename, old, verbose: true) if File.symlink?(basename)
      end
      rotate.call

      FileUtils.cp(sum.file, sum.value, verbose: true)
      FileUtils.ln_s(sum.value, basename)
    end
  end
end

Dir.chdir(dep11_dir) do
  cmd.run! 'tree'
end

Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives',
                keys: ENV.fetch('SSH_KEY_FILE'), keys_only: true) do |sftp|
  puts sftp.session.exec!("rm -rf #{tmpdir}")
  puts sftp.session.exec!("mkdir -p #{tmpdir}")

  sftp.upload!("#{repo_dir}/", tmpdir)

  puts sftp.session.exec!("mkdir -p #{targetdir}/")
  puts sftp.session.exec!("cp -rv #{tmpdir}/. #{targetdir}/")
end
FileUtils.rm_rf(repo_dir)

pubdir = "/srv/www/metadata.neon.kde.org/appstream/#{TYPE}_#{DIST}"

# This is the export dep11 data, we don't need it, so throw it away
system("rm -rf #{export_data_dir}")
# NB: We use rsync here because a) SFTP is dumb and may require copying things
#   to tmp path, removing pubdir and moving tmpdir to pubdir, while rsync will
#   be faster.
remote_dir = "metadataneon@charlotte.kde.org:#{pubdir}"
ssh_command = "ssh -o StrictHostKeyChecking=no -i #{ENV.fetch('SSH_KEY_FILE')}"
rsync_opts = "-av -e '#{ssh_command}'"
system("rsync #{rsync_opts} #{export_dir}/* #{remote_dir}/") || raise
