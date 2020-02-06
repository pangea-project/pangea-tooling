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

require 'tty-command'
require 'docker'

## TODO: This needs to pull in values from YAML config files.
cmd = TTY::Command.new
DIST = ENV.fetch('DIST')
arch = ENV.fetch('ARCH')

cmd.run('sudo apt -y install binfmt-support qemu qemu-user-static debootstrap')

  unless File.exist?("stable-#{arch}") || File.exist?("#{arch}.tar.bz2")
    puts "Building Image for #{arch}"
    cmd.run("sudo qemu-debootstrap --arch=#{arch} stable ./stable-#{arch} http://deb.debian.org/debian")
  end

  if File.exist?("stable-#{arch}")
    cmd.run("sudo chroot ./stable-#{arch} apt-get clean")
    cmd.run("sudo chroot ./stable-#{arch} apt-get autoclean")
    cmd.run("sudo chroot ./stable-#{arch} apt-get -y install git awscli pigz live-build vim make")
    cmd.run("sudo chroot ./stable-#{arch} sed --in-place=.bak -e 's|umount \"$TARGET/proc\" 2>/dev/null \\|\\| true|#umount \"$TARGET/proc\" 2>/dev/null \\|\\| true|g' /usr/share/debootstrap/functions")
    cmd.run("sudo chroot ./stable-#{arch} cat /usr/share/debootstrap/functions | grep '#umount \"$TARGET/proc\" 2>/dev/null'")
    cmd.run("sudo chroot ./stable-#{arch} mkdir /usr/local/share/ca-certificates/cacert.org")
    cmd.run("sudo chroot ./stable-#{arch} wget -P /usr/local/share/ca-certificates/cacert.org http://www.cacert.org/certs/root.crt http://www.cacert.org/certs/class3.crt")
    cmd.run("sudo chroot ./stable-#{arch} update-ca-certificates")
  else
    puts "stable-#{arch} does not exist, if  this is first run, something failed"
  end
  unless File.exist?("#{arch}.tar.bz2")
    cmd.run("cd stable-#{arch} && sudo tar cjvf ../#{arch}.tar.bz2 . && cd ..")
  end
  if File.exist?("#{arch}.tar.bz2") && File.exist?("stable-#{arch}")
    cmd.run("sudo rm -rfv stable-#{arch}")
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
