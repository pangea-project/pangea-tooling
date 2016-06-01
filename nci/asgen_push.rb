#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
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
require 'net/ssh'

archive_dir = File.absolute_path('aptly-repository')
run_dir = File.absolute_path('run')

# Mangle the Release file.
export_dir = "#{run_dir}/export"
repo_dir = "#{export_dir}/repo"
dep11_dir = "#{repo_dir}/main/dep11"
FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
FileUtils.mkpath(dep11_dir)
FileUtils.cp_r("#{export_dir}/data/xenial/main/.", dep11_dir, verbose: true)

release = Debian::Release.new("#{archive_dir}/dists/xenial/Release")
release.parse!

def checksum(tool, f)
  puts "#{tool} #{f}"
  sum = `#{tool} #{f}`.strip.split(' ')[0]
  raise unless $? == 0
  size = File.size(f)
  name = f.split('main/dep11/')[-1]
  Debian::Release::Checksum.new(sum, size, "main/dep11/#{name}")
end

Dir.glob("#{dep11_dir}/*").each do |f|
  %w(MD5Sum SHA1 SHA256 SHA512).each do |s|
    tool = "#{s.downcase}sum"
    tool = tool.gsub('sumsum', 'sum') # make sure md5sumsum becomes md5sum
    release.fields[s] << checksum(tool, f)
    next unless f.end_with?('.gz')
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        FileUtils.cp(f, Dir.pwd)
        basename = File.basename(f)
        system("gunzip #{basename}") || raise
        release.fields[s] << checksum(tool, basename.gsub('.gz', ''))
      end
    end
  end
end
File.write("#{repo_dir}/Release", release.dump)

repodir = File.absolute_path('run/export/repo')
tmpdir = '/home/nci/asgen_push'
targetdir = "/home/nci/aptly/#{ENV.fetch('APTLY_REPOSITORY')}/dists/xenial"

Net::SSH.start('localhost', 'nci') do |ssh|
  puts ssh.exec!("rm -rf #{tmpdir}")
  puts ssh.exec!("mkdir -p #{tmpdir}")
  puts ssh.exec!("cp -rv #{repodir}/. #{tmpdir}")
  puts ssh.exec!("gpg --digest-algo SHA256 --armor -s -o #{tmpdir}/InRelease --clearsign #{tmpdir}/Release")
  puts ssh.exec!("gpg --digest-algo SHA256 --armor --detach-sign -s -o #{tmpdir}/Release.gpg  #{tmpdir}/Release")
  puts ssh.exec!("cp -rv #{tmpdir}/. #{targetdir}/")
end
