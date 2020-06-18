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

require 'digest'
require 'net/sftp'
require 'nokogiri'
require 'open-uri'
require 'tty-command'
require_relative '../ci-tooling/lib/nci'
require_relative 'lib/imager_push_paths'

STDOUT.sync = true # Make sure output is synced and bypass caching.

# Torrent piece size
PIECE_LENGTH = 262_144

key_file = ENV.fetch('SSH_KEY_FILE', nil)
ssh_args = key_file ? [{ keys: [key_file] }] : []

def fix_meta4(path)
  meta4_doc = Nokogiri::XML(File.open(path))
  meta4_doc.remove_namespaces!

  meta4_doc.xpath('//metalink/file').each do |file|
    filename = file.attribute('name').value
    raise '<file> not found in meta4' if filename.empty?

    pieces_node = file.at_xpath('./pieces')
    next if pieces_node

    warn '!!! No pieces data available yet! Need to generate it manually !!!'

    filename = "result/#{filename}" # during pushing we have stuff in a subdir
    raise "#{filename} doesn't exist" unless File.exist?(filename)

    size = file.at_xpath('./size').content.to_i
    raise 'Size not valid in meta4' unless size >= 0
    unless File.size(filename) == size
      raise "Size in meta4 different #{size} vs #{File.size(filename)}"
    end

    # Otherwise create the node

    pieces_node = Nokogiri::XML::Node.new('pieces', meta4_doc)
    pieces_node['length'] = PIECE_LENGTH
    pieces_node['type'] = 'sha1'
    file.add_child(pieces_node)

    filedigest = Digest::SHA1.new
    File.open(filename) do |f|
      loop do
        data = f.read(PIECE_LENGTH)
        break unless data

        filedigest.update(data)
        sha = Digest::SHA1.hexdigest(data)
        pieces_node.add_child("<hash>#{sha}</hash>\n")
      end
    end
    # NB: the python thingy also needs the sha1 of the complete file to
    # accept the piece information!
    file.add_child("<hash type='sha-1'>#{filedigest.hexdigest}</hash>\n")
  end

  File.write(path, meta4_doc.to_xml)
end

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
    # Download the torrent over sftp lest we get funny redirects. Mirrobrain
    # redirects https to http and open-uri gets angry (rightfully).
    torrent_path = "#{remote_dir_path}/#{torrent_name}"
    sftp.stat!(torrent_path) # only care if it raises anything
    sftp.download!(torrent_path, torrent_name)
  rescue Net::SFTP::StatusException => e
    raise e unless e.code == Net::SFTP::Constants::StatusCodes::FX_NO_SUCH_FILE

    puts "Torrent #{torrent_path} doesn't exist yet!"
  end

  # Fix meta4, but only if we have no torrent file. We don't need piece info
  # if we already have a torrent as we only extend the seed list.
  fix_meta4(meta4_name) unless File.exist?(torrent_name)

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
