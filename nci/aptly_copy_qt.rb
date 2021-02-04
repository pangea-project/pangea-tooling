#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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
require 'logger'
require 'logger/colors'
require 'net/ssh/gateway'
require 'ostruct'
require 'optparse'

require_relative '../lib/aptly-ext/filter'
require_relative '../lib/nci'
require_relative '../lib/aptly-ext/remote'

# options = OpenStruct.new
# parser = OptionParser.new do |opts|
#   opts.banner = "Usage: #{opts.program_name} SOURCENAME"

#   opts.on('-r REPO', '--repo REPO',
#           'Repo to delete from [can be used >1 time]') do |v|
#     options.repos ||= []
#     options.repos << v.to_s
#   end
# end
# parser.parse!

# abort parser.help unless ARGV[0] && options.repos
# options.name = ARGV[0]

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

# SSH tunnel so we can talk to the repo
Aptly::Ext::Remote.neon do
  repo = Aptly::Repository.get("experimental_#{NCI.current_series}")
  raise unless repo

  # FIXME: this is a bit ugh because the repo isn't cleaned. Ideally we should
  # just be able to query all packages and sources of qt*-opensource* and
  # that should be the final list. Since the repo is dirty we need to manually
  # filter the latest sources and then query their related binaries.

  sources =
    repo.packages(q: 'Name (% qt*-opensource-*), $Architecture (source)')
  sources = Aptly::Ext::LatestVersionFilter.filter(sources)

  query = ''
  sources.each do |src|
    query += ' | ' unless query.empty?
    query += "($Source (#{src.name}), $Version (= #{src.version}))"
  end

  binaries = repo.packages(q: query)
  binaries = binaries.collect { |x| Aptly::Ext::Package::Key.from_string(x) }
  packages = (sources + binaries).collect(&:to_s)

  puts "Going to copy: #{packages.join("\n")}"

  # Only needed in unstable, we want to do one rebuild there anyway, so
  # publishing to the other repos is not necessary as the rebuild will take
  # care of that.
  target_repo = Aptly::Repository.get("unstable_#{NCI.current_series}")
  raise unless target_repo

  target_repo.add_packages(packages)
  target_repo.published_in.each(&:update!)
end
