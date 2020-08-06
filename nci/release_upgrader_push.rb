#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

APTLY_REPOSITORY = ENV.fetch('APTLY_REPOSITORY')
DIST = ENV.fetch('DIST')

# TODO: current? version cleanup? rotating?
#   ubuntu publishes them as ...-all/1.2.3/focal.tar.gz etc. and keeps ~3
#   versions. they also keep a current folder which is probably simply a symlink
#   or copy of the latest version. seems a bit useless IMO so I haven't written
#   any code for that and all goes into current currently. -sitter
home = '/home/neonarchives'
targetdir = "#{home}/aptly/skel/#{APTLY_REPOSITORY}/dists/#{DIST}/main/dist-upgrader-all"

Dir.chdir('DistUpgrade')
Dir.mktmpdir('release_upgrader_push') do |tmpdir|
  remote_tmp = "#{home}/#{File.basename(tmpdir)}"

  puts File.basename(tmpdir)

  SIGNER = <<-CODE
    set -x
    cd #{remote_tmp}
    for tar in */*.tar.gz; do
      echo "Signing $tar"
      gpg --digest-algo SHA256 --armor --detach-sign -s -o $tar.gpg $tar
    done
  CODE

  # Grab, key form environment when run on jenkins.
  opts = {}
  if (key = ENV['SSH_KEY_FILE'])
    opts[:keys] = [key, File.expand_path('~/.ssh/id_rsa')]
  end

  Net::SFTP.start('archive-api.neon.kde.org', 'neonarchives', **opts) do |sftp|
    ssh = sftp.session
    begin
      puts ssh.exec!("rm -rf #{remote_tmp}")

      dirs = Dir.glob('*.*.*')
      raise 'no dir matches found' if dirs.empty?
      dirs.each do |dir|
        next unless File.directory?(dir)
        raise 'tar count wrong' unless Dir.glob("#{dir}/*.tar.gz").size == 1

        # name = File.basename(dir)
        name = 'current'
        target = "#{remote_tmp}/#{name}"

        puts "#{dir} -> #{target}"
        puts ssh.exec!("mkdir -p #{target}")
        sftp.upload!(dir, target)
      end

      puts ssh.exec!(SIGNER)

      puts ssh.exec!("mkdir -p #{targetdir}/")
      puts ssh.exec!("cp -rv #{remote_tmp}/. #{targetdir}/")
    ensure
      puts ssh.exec!("rm -rf #{remote_tmp}")
    end
  end
end
