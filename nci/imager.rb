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
exit status_code unless status_code.to_i.zero?

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

Net::SFTP.start('racnoss.kde.org', 'neon') do |sftp|
  sftp.mkdir!(REMOTE_PUB_DIR)
  types = %w(amd64.iso amd64.iso.sig manifest zsync sha256sum)
  types.each do |type|
    Dir.glob("result/*#{type}").each do |file|
      name = File.basename(file)
      STDERR.puts "Uploading #{file}..."
      sftp.upload!(file, "#{REMOTE_PUB_DIR}/#{name}")
    end
  end

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
    sftp.rmdir!(path)
  end
end

Net::SFTP.start('weegie.edinburghlinux.co.uk', 'neon') do |sftp|
  path = 'files.neon.kde.org.uk'
  types = %w(source.tar.xz)
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

exit 0
