#!/usr/bin/env ruby
#
# Copyright (C) 2015 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'ostruct'

require_relative 'lib/lp'

component = ENV['COMPONENT']
type = ENV['TYPE']
name = ENV['NAME']

# Only unstable -> stable
if type != 'unstable'
  puts 'Not doing a package copy because the component is not "unstable"'
  exit
end

copy_sources = %w[qca-qt5 qapt debconf-kde]
if !copy_sources.include?(name) && component != 'frameworks'
  puts 'Not doing a package copy because the component is not "frameworks"' \
       " nor is the name whitelisted #{copy_sources}"
  exit
end

puts '!!! Copying packages to stable !!!'

# FIXME: yolo
distribution = ENV['DIST']
source = JSON.parse(File.read('source.json'), object_class: OpenStruct)

Launchpad.authenticate

# FIXME: current assumptions: source is unstable, target is always stable
ppa_base = '~kubuntu-ci/+archive/ubuntu'
source_ppa = Launchpad::Rubber.from_path("#{ppa_base}/unstable")
target_ppa = Launchpad::Rubber.from_path("#{ppa_base}/stable")
series = Launchpad::Rubber.from_path("ubuntu/#{distribution}")

source_ppa.getPublishedSources(source_name: source.name,
                               version: source.version,
                               distro_series: series,
                               exact_match: true).each do |s|
  target_ppa.copyPackage!(from_archive: source_ppa,
                          source_name: s.source_package_name,
                          version: s.source_package_version,
                          to_pocket: 'Release',
                          include_binaries: true)
end
