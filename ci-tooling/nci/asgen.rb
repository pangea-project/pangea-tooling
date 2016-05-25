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

require 'fileutils'
require 'tmpdir'

require_relative '../lib/apt'
require_relative '../lib/asgen'
require_relative '../lib/debian/release'

# Build
Apt.install(%w(dub libappstream-dev libgdk-pixbuf2.0-dev libarchive-dev
               librsvg2-dev liblmdb-dev libglib2.0-dev libcairo2-dev
               libcurl4-gnutls-dev)) || raise

system('make update-submodule') || raise
system('dub build --parallel') || raise

# Run
Apt.install(%w(npm nodejs-legacy optipng liblmdb0)) || raise

system(*%w(npm install -g bower)) || raise
# This needs pitchy patching in the config script to enable usage as root.
system(*%w(make js)) || raise

config = ASGEN::Conf.new('neon/user')
config.dataPriority = 1
config.ArchiveRoot = File.absolute_path('public/user')
config.MediaBaseUrl = 'http://metadata.tanglu.org/appstream/media'
config.HtmlBaseUrl = 'http://metadata.tanglu.org/appstream/'
config.Backend = 'debian'
config.Features['validateMetainfo'] = true
config.Suites << ASGEN::Suite.new('xenial', ['main'], ['amd64'])

build_dir = File.absolute_path('build')
run_dir = File.absolute_path('run')
FileUtils.mkpath(run_dir) unless Dir.exist?(run_dir)
config.write("#{run_dir}/asgen-config.json")
system("#{build_dir}/appstream-generator", 'process', 'xenial',
       chdir: run_dir) || raise

# TODO
# [15:03] <ximion> sitter: the version number changing isn't an issue - it does nothing with one architecture, and it's an optimization if you have at least one other architecture.
# [15:03] <ximion> sitter: you should run ascli cleanup every once in a while though, to collect garbage

export_dir = "#{run_dir}/export"
repo_dir = "#{export_dir}/repo"
dep11_dir = "#{repo_dir}/main/dep11"
FileUtils.rm_r(repo_dir) if Dir.exist?(repo_dir)
FileUtils.mkpath(dep11_dir)
FileUtils.cp_r("#{export_dir}/data/xenial/main/.", dep11_dir, verbose: true)

release = Debian::Release.new("#{config.ArchiveRoot}/dists/xenial/Release")
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
