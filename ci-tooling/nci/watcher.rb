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

#puts 'mangling debian/watch'
#output = ''
#File.open('debian/watch').each do |line|
#  output += line.gsub(%r{download.kde.org/stable/applications},
#                      'download.kde.org.uk/stable/applications')
#end
#puts output
#File.open('debian/watch', 'w') { |file| file.write(output) }
#puts 'mangled debian/watch'

if File.readlines("debian/watch").grep(/unstable/).any?
  puts "Quitting watcher as debian/watch contains unstable and we only build stable tars in Neon"
  exit 0
end

data = `uscan --report --dehs`
puts "uscan failed (#{$?}) :: #{data}"

newer = Debian::UScan::DEHS.parse_packages(data).collect do |package|
  next nil unless package.status == Debian::UScan::States::NEWER_AVAILABLE
  package
end.compact
pp newer

exit 0 if newer.empty?

merged = false
if system('git merge origin/Neon/stable')
  merged = true
  newer.reject! { |x| !x.upstream_url.include?('stable') }
elsif system('git merge origin/Neon/unstable')
  merged = true
  # Do not filter paths when unstable was merged. We use unstable as common
  # branch, so e.g. frameworks have only Neon/unstable but their download path
  # is http://download.kde.org/stable/frameworks/...
  # We thusly cannot kick stable.
end
raise 'Could not merge anything' unless merged

newer = newer.group_by(&:upstream_version)
newer = Hash[newer.map { |k, v| [Debian::Version.new(k), v] }]
newer = newer.sort.to_h
newest = newer.keys[-1]

puts "newest #{newest.inspect}"
raise 'No newest version found' unless newest

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

# FIXME: almost code copy from sourcer_base
# --- Unset revision from this point on, so we get the base version ---
version.revision = nil
something_changed = false
Dir.glob('debian/*') do |path|
  next unless path.end_with?('changelog', 'control', 'rules')
  next unless File.file?(path)
  data = File.read(path)
  begin
    source_change = data.gsub!('${source:Version}~ciBuild', version.to_s)
    binary_change = data.gsub!('${binary:Version}~ciBuild', version.to_s)
    something_changed ||= !(source_change || binary_change).nil?
  rescue
    raise "Failed to gsub #{path}"
  end
  File.write(path, data)
end

system('wrap-and-sort') if something_changed

system('git checkout debian/watch')
system('git diff')
system("git commit -a -m 'New release'")
