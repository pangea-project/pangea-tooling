#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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
DATE = File.read('date_stamp').strip
IMGNAME="#{IMAGENAME}-pinebook-remix-#{TYPE}-#{DATE}-#{ARCH}"
REMOTE_DIR = "public_html/images/pinebook-remix/"
REMOTE_PUB_DIR = "#{REMOTE_DIR}/#{DATE}"

puts "GPG signing disk image file"
unless system('gpg2', '--armor', '--detach-sign', '-o',
              "#{IMGNAME}.img.sig",
              "#{IMGNAME}.img")
  raise 'Failed to sign'
end

# Publish ISO and associated content.
Net::SFTP.start('weegie.edinburghlinux.co.uk', 'neon') do |sftp|
  puts "mkdir #{REMOTE_PUB_DIR}"
  sftp.mkdir!(REMOTE_PUB_DIR)
  types = %w[arm64.img.gz arm64.img.sig contents zsync sha256sum]
  types.each do |type|
    Dir.glob("*#{type}").each do |file|
      name = File.basename(file)
      STDERR.puts "Uploading #{file}..."
      sftp.upload!(file, "#{REMOTE_PUB_DIR}/#{name}")
    end
  end

  # Need a second SSH session here, since the SFTP one is busy looping.
  Net::SSH.start('weegie.edinburghlinux.co.uk', 'neon') do |ssh|
    ssh.exec!("cd #{REMOTE_PUB_DIR}; gunzip --stdout *img.gz > #{IMGNAME}.img")
    ssh.exec!("cd #{REMOTE_PUB_DIR};" \
              " ln -s *img #{IMAGENAME}-pinebook-remix-#{TYPE}-current.iso")
    ssh.exec!("cd #{REMOTE_PUB_DIR};" \
              " ln -s *img.sig #{IMAGENAME}-pinebook-remix-#{TYPE}-current.img.sig")
    ssh.exec!("cd #{REMOTE_DIR}; rm -f current; ln -s #{DATE} current")
  end

  # delete old directories
  img_directories = sftp.dir.glob(REMOTE_DIR, '*').collect(&:name)
  img_directories.delete('current') # keep current symlink
  img_directories = img_directories.sort.pop(4) # keep the latest four builds
  img_directories.each do |name|
    path = "#{REMOTE_DIR}/#{name}"
    STDERR.puts "rm #{path}"
    sftp.dir.glob(path, '*') { |e| sftp.remove!("#{path}/#{e.name}") }
    sftp.rmdir!(path)
  end
end

# Publish ISO sources.
=begin
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
=end
