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
require 'tty-command'

DIST = ENV.fetch('DIST')
TYPE = ENV.fetch('TYPE')
ARCH = ENV.fetch('ARCH')
IMAGENAME = ENV.fetch('IMAGENAME')

# copy to depot using same directory without -proposed for now, later we want
# this to only be published if passing some QA test
DATE = File.read('result/date_stamp').strip
ISONAME = "#{IMAGENAME}-#{TYPE}"
REMOTE_DIR = "neon/images/#{ISONAME}/"
REMOTE_PUB_DIR = "#{REMOTE_DIR}/#{DATE}"

unless TTY::Command.new.run('gpg2', '--armor', '--detach-sign', '-o',
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
  File.write("#{file}.README", <<-README_CONTENT)
zsync does not support HTTPs, since we prefer HTTPs rather than HTTP, this is a
problem.

We recommend that you download the file from a mirror over HTTP rather than
HTTPs and additionally download the .gpg signature to verify that the file you
downloaded is in fact the correct ISO signed by the key listed on
https://neon.kde.org/download
To find a suitable mirror have a look at the mirror list. You can access
the mirror list by appending .mirrorlist to the zsync URL.
e.g. https://files.kde.org/neon/images/neon-useredition/current/neon-useredition-current.iso.zsync.mirrorlist

Note that downloading from http://files.kde.org will always switch to https,
you need an actual mirror URL to use zsync over http.

If you absolutely want to zsync over HTTPs you have to use a zsync fork which
supports HTTPs (e.g. [1]). Do note that zsync-curl in particular will offer
incredibly bad performance due to lack of threading and libcurl's IO-overhead.
Unless you want to save data on a metered connection you will, most of the time,
see much shorter downloads when downloading an entirely new ISO instead of using
zsync-curl (even on fairly slow connections and even if the binary delta is
small, in fact small deltas are worse for performance with zsync-curl).

[1] https://github.com/probonopd/zsync-curl
README_CONTENT
end

# Monkey prepend a different upload method which uses sftp from openssh-client
# instead of net-sftp. net-sftp suffers from severe performance problems
# in part (probably) because of the lack of threading, more importantly because
# it implements CTR in ruby which is hella inefficient (half the time of writing
# is being spent in CTR alone)
module SFTPSessionOverlay
  def __cmd
    @__cmd ||= TTY::Command.new
  end

  def cli_uploads
    @use_cli_sftp ||= false
  end

  def cli_uploads=(enable)
    @use_cli_sftp = enable
  end

  def __cli_upload(from, to)
    remote = format('%<user>s@%<host>s',
                    user: session.options[:user],
                    host: session.host)
    key_file = ENV.fetch('SSH_KEY_FILE', nil)
    identity = key_file ? ['-i', key_file] : []
    __cmd.run('sftp', *identity, '-b', '-', remote,
              stdin: <<~STDIN)
                put #{from} #{to}
                quit
              STDIN
  end

  def upload!(from, to, **kwords)
    return super unless @use_cli_sftp
    raise 'CLI upload of dirs not implemented' if File.directory?(from)
    # cli wants dirs for remote location
    __cli_upload(from, File.dirname(to))
  end
end
class Net::SFTP::Session
  prepend SFTPSessionOverlay
end

key_file = ENV.fetch('SSH_KEY_FILE', nil)
ssh_args = key_file ? [{ keys: [key_file] }] : []

# Publish ISO and associated content.
Net::SFTP.start('racnoss.kde.org', 'neon', *ssh_args) do |sftp|
  sftp.cli_uploads = true
  sftp.mkdir!(REMOTE_PUB_DIR)
  types = %w[amd64.iso amd64.iso.sig manifest zsync zsync.README sha256sum]
  types.each do |type|
    Dir.glob("result/*#{type}").each do |file|
      name = File.basename(file)
      sftp.cli_uploads = File.new(file).lstat.size > 4 * 1024 * 1024
      STDERR.puts "Uploading #{file} (via cli: #{sftp.cli_uploads})... "
      sftp.upload!(file, "#{REMOTE_PUB_DIR}/#{name}")
    end
  end
  sftp.cli_uploads = false
  sftp.upload!('result/.message', "#{REMOTE_PUB_DIR}/.message")

  # Need a second SSH session here, since the SFTP one is busy looping.
  Net::SSH.start('racnoss.kde.org', 'neon', *ssh_args) do |ssh|
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
    sftp.dir.foreach(path) do |e|
      next if %w[. ..].include?(e.name)
      sftp.remove!("#{path}/#{e.name}")
    end
    sftp.rmdir!(path)
  end
end

Net::SSH.start('files.kde.mirror.pangea.pub', 'neon-image-sync',
               *ssh_args) do |ssh|
  status = {}
  ssh.exec!('./sync', status: status) do |_channel, stream, data|
    (stream == :stderr ? STDERR : STDOUT).puts(data)
  end
  raise 'Failed sync' unless status.fetch(:exit_code, 1).zero?
end

# Publish ISO sources.
Net::SFTP.start('weegie.edinburghlinux.co.uk', 'neon', *ssh_args) do |sftp|
  path = 'files.neon.kde.org.uk'
  types = %w[source.tar.xz source.tar]
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

      sftp.cli_uploads = File.new(file).lstat.size > 4 * 1024 * 1024
      STDERR.puts "Uploading #{file} (via cli: #{sftp.cli_uploads})... "
      sftp.upload!(file, "#{path}/#{name}")
    end
  end
end
