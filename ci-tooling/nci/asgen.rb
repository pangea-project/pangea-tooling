#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016-2018 Harald Sitter <sitter@kde.org>
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
require_relative '../lib/nci'

TYPE = ENV.fetch('TYPE')
DIST = ENV.fetch('DIST')

NCI.setup_repo!

File.open('/etc/apt/sources.list', 'a') do |file|
  file.write(<<-SOURCES)
deb http://archive.ubuntu.com/ubuntu/ #{DIST}-backports main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ #{DIST}-updates main restricted universe multiverse
  SOURCES
end

# Build
Apt.update
Apt.install(%w[meson ldc gir-to-d libappstream-dev libgdk-pixbuf2.0-dev
               libarchive-dev librsvg2-dev liblmdb-dev libglib2.0-dev
               libcairo2-dev libcurl4-gnutls-dev libfreetype6-dev
               libfontconfig1-dev libpango1.0-dev libmustache-d-dev]) || raise

# Run
Apt.install(%w[npm nodejs-legacy optipng liblmdb0]) || raise

system(*%w[npm install -g bower]) || raise

build_dir = File.absolute_path('build')
run_dir = File.absolute_path('run')

Dir.chdir(build_dir) do
  system(*%w[meson -Ddownload_js=true ..])
  system(*%w[ninja])
end

suite = DIST
config = ASGEN::Conf.new("neon/#{TYPE}")
config.ArchiveRoot = File.absolute_path('aptly-repository')
config.MediaBaseUrl = "https://metadata.neon.kde.org/appstream/#{TYPE}/media"
config.HtmlBaseUrl = "https://metadata.neon.kde.org/appstream/#{TYPE}/html"
config.Backend = 'debian'
config.Features['validateMetainfo'] = true
config.Suites << ASGEN::Suite.new(series).tap do |s|
  s.sections = %w[main]
  s.architectures = %w[amd64]
  s.dataPriority = 1
  s.useIconTheme = 'breeze'
end

# Generate
# Install theme to hopefully override icons with breeze version.
# TODO: This currently isn't using the actual neon version.
Apt.install('breeze-icon-theme', 'hicolor-icon-theme')
FileUtils.mkpath(run_dir) unless Dir.exist?(run_dir)
config.write("#{run_dir}/asgen-config.json")
system("#{build_dir}/appstream-generator", 'process', suite,
       chdir: run_dir) || raise

# TODO
# [15:03] <ximion> sitter: the version number changing isn't an issue -
# it does nothing with one architecture, and it's an optimization if you have
# at least one other architecture.
# [15:03] <ximion> sitter: you should run ascli cleanup every once in a while
# though, to collect garbage
