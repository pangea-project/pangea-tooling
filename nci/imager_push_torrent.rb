#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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
require 'open-uri'
require 'tty-command'

STDOUT.sync = true # Make sure output is synced and bypass caching.

TYPE = ENV.fetch('TYPE')

REMOTE_DIR = "neon/images/#{TYPE}/"

key_file = ENV.fetch('SSH_KEY_FILE', nil)
ssh_args = key_file ? [{ keys: [key_file] }] : []

Net::SFTP.start('master.kde.org', 'neon', *ssh_args) do |sftp|
  iso = nil
  sftp.dir.glob(REMOTE_DIR, '*/*.iso') do |entry|
    next if entry.name.include?('-current')
    raise "Found two isos wtf. already have #{iso}, now also #{entry}" if iso

    iso = entry
  end

  raise 'Could not find remote iso file!' unless iso

  dir = File.dirname(iso.name)
  remote_dir_path = File.join(REMOTE_DIR, dir)
  meta4_name = File.basename("#{iso.name}.meta4")
  meta4_url = "https://files.kde.org/#{remote_dir_path}/#{meta4_name}"
  torrent_name = File.basename("#{iso.name}.torrent")
  torrent_url = "https://files.kde.org/#{remote_dir_path}/#{torrent_name}"

  File.write(meta4_name, open(meta4_url).read)
  begin
    File.write(torrent_name, open(torrent_url).read)
  rescue OpenURI::HTTPError => e
    raise e if e.io.status[0] != '404'

    puts "Torrent doesn't exist yet!"
  end

  cmd = TTY::Command.new(uuid: false)
  # Run a harness to setup a container. We need a container since the host
  # doesn't have the necessary software and I can't be bothered to fix that
  # container just makes it a bit slower. It matters little.
  cmd.run "#{__dir__}/contain.rb /tooling/nci/generate_torrent.rb #{meta4_name} #{torrent_name}"

  unless File.exist?(torrent_name)
    cmd.run!('ls -lah')
    raise "Generator ran but torrent doesn't exist!"
  end

  sftp.upload!(torrent_name, File.join(remote_dir_path, torrent_name))
end
