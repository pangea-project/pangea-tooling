#!/usr/bin/env ruby
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

# Watches for releases via uscan.

require 'pp'

require_relative '../lib/debian/changelog'
require_relative '../lib/debian/uscan'
require_relative '../lib/debian/version'
require_relative '../lib/nci'
require_relative 'lib/setup_env'

# FIXME: needs tests

NCI.setup_env!

abort 'No debain/watch found!' unless File.exist?('debian/watch')

data = `uscan --report --dehs`

newer = Debian::UScan::DEHS.parse_packages(data).collect do |package|
  next nil unless package.status == Debian::UScan::States::NEWER_AVAILABLE
  package
end.compact
pp newer

exit 0 if newer.empty?

merged = (system('git merge origin/Neon/stable') || system('git merge origin/Neon/unstable'))
raise 'Could not merge anything' unless merged

newer = newer.group_by(&:upstream_version)
newer = Hash[newer.map { |k, v| [Debian::Version.new(k), v] }]
newer = newer.sort.to_h
newest = newer.keys[-1]

puts "newest #{newest.inspect}"

version = Debian::Version.new(Changelog.new(Dir.pwd).version)
version.upstream = newest
version.revision = '0neon' if version.revision && !version.revision.empty?

# FIXME: stolen from sourcer
dch = [
  'dch',
  '--distribution', NCI.latest_series,
  '--newversion', version.to_s,
  'New release'
]
# dch cannot actually fail because we parse the changelog beforehand
# so it is of acceptable format here already.
raise 'Failed to create changelog entry' unless system(*dch)

system('git diff')
system("git commit -a -m 'New release'")
