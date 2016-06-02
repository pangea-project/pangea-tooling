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

require_relative 'lib/setup_repo'
require_relative '../lib/apt'
require_relative '../lib/asgen'

NCI.setup_repo!

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

config = ASGEN::Conf.new("neon/#{TYPE}")
config.ArchiveRoot = File.absolute_path('aptly-repository')
config.MediaBaseUrl = "http://metadata.neon.kde.org/appstream/#{TYPE}/media"
config.HtmlBaseUrl = "http://metadata.neon.kde.org/appstream/#{TYPE}/html"
config.Backend = 'debian'
config.Features['validateMetainfo'] = true
config.Suites << ASGEN::Suite.new('xenial', ['main'], ['amd64']).tap do |s|
  s.dataPriority = 1
  s.useIconTheme = 'breeze'
end

# Generate
# Install theme to hopefully override icons with breeze version.
# TODO: This currently isn't using the actual neon version.
Apt.install('breeze-icon-theme', 'hicolor-icon-theme')
build_dir = File.absolute_path('build')
run_dir = File.absolute_path('run')
FileUtils.mkpath(run_dir) unless Dir.exist?(run_dir)
config.write("#{run_dir}/asgen-config.json")
system("#{build_dir}/appstream-generator", 'process', 'xenial',
       chdir: run_dir) || raise

# TODO
# [15:03] <ximion> sitter: the version number changing isn't an issue - it does nothing with one architecture, and it's an optimization if you have at least one other architecture.
# [15:03] <ximion> sitter: you should run ascli cleanup every once in a while though, to collect garbage
