#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Scarlett Moore <sgmoore@kde.org>
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

require 'concurrent-ruby'
require 'tty-command'
require 'docker'

threads = []

## TODO: This needs to pull in values from YAML config files.
archs = %w[amd64 arm64 armhf]
cmd = TTY::Command.new
DIST = ENV.fetch('DIST')

cmd.run('sudo apt -y install binfmt-support qemu qemu-user-static debootstrap')
pool =
  Concurrent::ThreadPoolExecutor.new(
    min_threads: 2,
    max_threads: 4,
    max_queue: 512,
    fallback_policy: :caller_runs
  )

archs.each do |arch|
  threads << Concurrent::Promise.execute(executor: pool) do
    unless File.exist?("testing-#{arch}") || File.exist?("#{arch}.tar.bz2")
      puts "Building Image for #{arch}"
      cmd.run("sudo qemu-debootstrap --arch=#{arch} testing ./testing-#{arch} http://deb.debian.org/debian")
    end
  end
end

Concurrent::Promise.zip(*threads).wait!

archs.each do |arch|
  if File.exist?("testing-#{arch}")
    cmd.run("sudo chroot ./testing-#{arch} apt-get clean")
    cmd.run("sudo chroot ./testing-#{arch} apt-get autoclean")
    cmd.run("sudo chroot ./testing-#{arch} apt-get -y install git awscli pigz live-build vim make")
    cmd.run("sudo chroot ./testing-#{arch} sed --in-place=.bak -e 's|umount \"$TARGET/proc\" 2>/dev/null \\|\\| true|#umount \"$TARGET/proc\" 2>/dev/null \\|\\| true|g' /usr/share/debootstrap/functions")
    cmd.run("sudo chroot ./testing-#{arch} cat /usr/share/debootstrap/functions | grep '#umount \"$TARGET/proc\" 2>/dev/null'")
  else
    puts "testing-#{arch} does not exist, if  this is first run, something failed"
  end
  unless File.exist?("#{arch}.tar.bz2")
    cmd.run("cd testing-#{arch} && sudo tar cjvf ../#{arch}.tar.bz2 . && cd ..")
  end
  if File.exist?("#{arch}.tar.bz2") && File.exist?("testing-#{arch}")
    cmd.run("sudo rm -rfv testing-#{arch}")
  end
  if File.exist?("#{arch}.tar.bz2")
    puts 'We have a tar, moving on'
  else
    puts 'Tar was not generated - something went wrong.'
  end
  unless Docker::Image.exist?("debianci/#{arch}:#{DIST}")
    File.open("#{arch}.tar.bz2") do |file|
      docker = Docker::Image.import_stream { file.read(10_000).to_s }
      docker.tag(repo: "debianci/#{arch}", tag: "#{DIST}")
    end
  end
  if Docker::Image.exist?("debianci/#{arch}:#{DIST}")
    puts "Docker image debianci/#{arch}:#{DIST} successful"
  else
    puts 'Something went wrong in docker image creation.'
  end
end
