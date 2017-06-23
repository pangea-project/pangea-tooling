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
require 'net/sftp'
require 'net/ssh'

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
IMAGENAME = ENV.fetch('IMAGENAME')

# copy to depot using same directory without -proposed for now, later we want
# this to only be published if passing some QA test
DATE = File.read('result/date_stamp').strip
ISONAME = "#{IMAGENAME}-#{TYPE}".freeze
REMOTE_DIR = "neon/images/#{ISONAME}/".freeze
REMOTE_PUB_DIR = "#{REMOTE_DIR}/#{DATE}".freeze

unless system('gpg2', '--armor', '--detach-sign', '-o',
              "result/#{ISONAME}-#{DATE}-amd64.iso.sig",
              "result/#{ISONAME}-#{DATE}-amd64.iso")
  raise 'Failed to sign'
end

# Add readme about zsync being defective.
# files.kde.org defaults to HTTPS (even redirects HTTP there), but zsync
# has no support and fails with a really stupid error. As fixing this
# server-side is something Ben doesn't want to do we'll simply tell the user
# to use a sane implementation or manually get a HTTP mirror url.
Dir.glob('result/*.zsync') do |file|
  File.write("#{file}.README", <<-EOF)
zsync does not support HTTPs, since we prefer HTTPs rather than HTTP this is a
problem.

If you would like to use zsync to download an ISO you either need to use a
libcurl based zsync implementation [1], or you need to need to manually find a
HTTP mirror from the mirror list. To get to the mirror list simply append
.mirrorlist to the zsync URL.
e.g. https://files.kde.org/neon/images/neon-useredition/current/neon-useredition-current.iso.zsync.mirrorlist

[1] https://github.com/probonopd/zsync-curl
EOF
end

# Publish ISO and associated content.
Net::SFTP.start('racnoss.kde.org', 'neon') do |sftp|
  sftp.mkdir!(REMOTE_PUB_DIR)
  types = %w[amd64.iso amd64.iso.sig manifest zsync zsync.README sha256sum]
  types.each do |type|
    Dir.glob("result/*#{type}").each do |file|
      name = File.basename(file)
      STDERR.puts "Uploading #{file}..."
      sftp.upload!(file, "#{REMOTE_PUB_DIR}/#{name}")
    end
  end
  sftp.upload!('.message', "#{REMOTE_PUB_DIR}/.message")

  # Need a second SSH session here, since the SFTP one is busy looping.
  Net::SSH.start('racnoss.kde.org', 'neon') do |ssh|
    ssh.exec!("cd #{REMOTE_PUB_DIR};" \
              " ln -s *amd64.iso #{ISONAME}-current.iso")
    ssh.exec!("cd #{REMOTE_PUB_DIR};" \
              " ln -s *amd64.iso.sig #{ISONAME}-current.iso.sig")
    ssh.exec!("cd #{REMOTE_DIR}; rm -f current; ln -s #{DATE} current")
  end

  sftp.dir.glob(REMOTE_DIR, '*') do |entry|
    next unless entry.directory? # current is a symlink
    path = "#{REMOTE_DIR}/#{entry.name}"
    next if path.include?(REMOTE_PUB_DIR)
    STDERR.puts "rm #{path}"
    sftp.dir.glob(path, '*') { |e| sftp.remove!("#{path}/#{e.name}") }
    sftp.remove!("#{path}/.message")
    sftp.rmdir!(path)
  end
end

# Publish ISO sources.
Net::SFTP.start('weegie.edinburghlinux.co.uk', 'neon') do |sftp|
  path = 'files.neon.kde.org.uk'
  types = %w[source.tar.xz]
  types.each do |type|
    Dir.glob("result/*#{type}").each do |file|
      # Remove old ones
      STDERR.puts "src rm #{path}/#{ISONAME}*#{type}"
      sftp.dir.glob(path, "#{ISONAME}*#{type}") do |e|
        STDERR.puts "glob src rm #{path}/#{e.name}"
        sftp.remove!("#{path}/#{e.name}")
      end
      # upload new one
      name = File.basename(file)
      STDERR.puts "Uploading #{file}..."
      sftp.upload!(file, "#{path}/#{name}")
    end
  end
end
