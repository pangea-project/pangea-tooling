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

require 'aptly'
require 'date'

require_relative '../lib/optparse'

parser = OptionParser.new do |opts|
  opts.banner =
    "Usage: #{opts.program_name} REPO_TO_DIVERT_TO_SNAPSHOT"
end
parser.parse!

Aptly.configure do |config|
  config.host = 'archive.neon.kde.org'
  # This is read-only.
end

all_pubs = Aptly::PublishedRepository.list
pubs = []
ARGV.each do |arg|
  pubs << all_pubs.find { |x| x.Prefix == arg }
end
packages_for_pubs = {}
pubs.each do |pub|
  packages_for_pubs[pub] = pub.Sources.collect(&:packages).flatten.uniq
end

packages_for_pubs.each_slice(2) do |x|
  one = x[0]
  two = x.fetch(1, nil)
  raise 'Uneven amount of publishing endpoints' unless two

  puts "\nOnly in #{one[0].Prefix}"
  puts((one[1] - two[1]).join($/))

  puts "\nOnly in #{two[0].Prefix}"
  puts((two[1] - one[1]).join($/))
end
