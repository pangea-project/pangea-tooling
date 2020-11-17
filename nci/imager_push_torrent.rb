#!/usr/bin/env ruby
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2019-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'bencode'
require 'digest'
require 'faraday'
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

def pieces(filename, size)
  filename = "result/#{filename}"
  unless File.size(filename) == size
    raise "Size in meta4 different #{size} vs #{File.size(filename)}"
  end

  pieces = []
  filedigest = Digest::SHA1.new
  File.open(filename) do |f|
    loop do
      data = f.read(PIECE_LENGTH)
      break unless data

      filedigest.update(data)
      sha = Digest::SHA1.hexdigest(data)
      pieces << sha
    end
  end

  # make a bytearray by joining into a long string, then foreach 2
  # characters treat them as hex and get their int. pack the array of int
  # as bytes to get the bytearray.
  pieces.join.scan(/../).map(&:hex).pack('C*')
end

Net::SFTP.start('rsync.kde.org', 'neon', *ssh_args) do |sftp|
  iso = nil
  sftp.dir.glob(REMOTE_DIR, '*/*.iso') do |entry|
    next if entry.name.include?('-current')
    raise "Found two isos wtf. already have #{iso}, now also #{entry}" if iso

    iso = entry
  end

  raise 'Could not find remote iso file!' unless iso

  dir = File.dirname(iso.name)
  remote_dir_path = File.join(REMOTE_DIR, dir)
  iso_filename = File.basename(iso.name)
  iso_url = "https://files.kde.org/#{remote_dir_path}/#{iso_filename}"
  torrent_name = File.basename("#{iso.name}.torrent")

  # https://fileformats.fandom.com/wiki/Torrent_file
  # NOTE: we could make this multi-file in the future, but need to check if
  # ktorrent wont't fall over. Needs refactoring too. What we'd want to do is
  # model each File entity so we can bencode them with minimal diff between
  # single-file format and multi-file.
  # http://getright.com/seedtorrent.html

  size = iso.attributes.size
  torrent = nil

  begin
    # Download the torrent over sftp lest we get funny redirects. Mirrobrain
    # redirects https to http and open-uri gets angry (rightfully).
    torrent_path = "#{remote_dir_path}/#{torrent_name}"
    sftp.stat!(torrent_path) # only care if it raises anything
    sftp.download!(torrent_path, torrent_name)

    torrent = BEncode::Parser.new(File.read(torrent_name)).parse!
  rescue Net::SFTP::StatusException => e
    raise e unless e.code == Net::SFTP::Constants::StatusCodes::FX_NO_SUCH_FILE

    puts "Torrent #{torrent_path} doesn't exist yet! Making new one."
  end

  torrent ||= {
    'announce' => 'udp://tracker.openbittorrent.com:80',
    'creation date' => Time.now.utc.to_i,
    'info' => {
      'piece length' => PIECE_LENGTH,
      'pieces' => pieces(iso_filename, size),
      'name' => iso_filename,
      'length' => size
    }
  }

  puts "Trying to obtain link list from #{iso_url}"
  # mirrorbits' link header contains mirror urls, use it to build the list.
  # <$url>; rel=$something; pri=$priority; geo=$region, <$url> ...
  # This is a bit awkward since link is entirely missing when there are
  # no mirrors yet, but that prevents us from telling when the headers break :|
  links = Faraday.get(iso_url).headers['link']&.scan(/<([^>]+)>/)&.flatten
  # In case we have zero mirror coverage make sure the main server is in the
  # list.
  links ||= [iso_url]

  # Rewrite url-list regardless of torrent having existed or not, we use this
  # to update the list when new mirrors appear.
  torrent['url-list'] = links

  File.write(torrent_name, torrent.bencode)

  remote_target = File.join(remote_dir_path, torrent_name)
  puts "Writing torrent to #{remote_target}"
  sftp.upload!(torrent_name, remote_target) do |*args|
    p args
  end
end
