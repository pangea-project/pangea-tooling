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
require 'logger'
require 'logger/colors'
require 'net/ssh/gateway'
require 'ostruct'
require 'optparse'

options = OpenStruct.new
parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{opts.program_name} SOURCENAME"
end
parser.parse!

abort parser.help unless ARGV[0]
options.name = ARGV[0]

log = Logger.new(STDOUT)
log.level = Logger::DEBUG
log.progname = $PROGRAM_NAME

# SSH tunnel so we can talk to the repo
gateway = Net::SSH::Gateway.new('archive-api.kde.org', 'neonarchives')
gateway.open('localhost', 9090, 9090)

Aptly.configure do |config|
  config.host = 'localhost'
  config.port = 9090
end

log.info 'APTLY'
Aptly::Repository.list.each do |repo|
  # next unless options.types.include?(repo.Name)

  # Query all relevant packages.
  # Any package with source as source.
  query = "($Source (#{options.name}))"
  # Or the source itself
  query += " | (#{options.name} {source})"
  packages = repo.packages(q: query).compact.uniq
  next if packages.empty?

  log.info "Deleting packages from repo #{repo.Name}: #{packages}"
  repo.delete_packages(packages)
  repo.published_in.each(&:update!)
end
