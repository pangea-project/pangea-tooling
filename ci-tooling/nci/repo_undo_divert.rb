#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
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
require 'net/ssh/gateway'

require_relative '../lib/optparse'

parser = OptionParser.new do |opts|
  opts.banner =
    "Usage: #{opts.program_name} REPO_TO_DIVERT_FROM_SNAPSHOT"
end
parser.parse!

unless parser.missing_expected.empty?
  puts "Missing expected arguments: #{parser.missing_expected.join(', ')}\n\n"
  abort parser.help
end

REPO_NAME = ARGV.last || nil
ARGV.clear
unless REPO_NAME
  puts "Missing repo name to divert\n\n"
  abort parser.help
end

# SSH tunnel so we can talk to the repo
gateway = Net::SSH::Gateway.new('drax', 'root')
gateway_port = gateway.open('localhost', 9090)

Aptly.configure do |config|
  config.host = 'localhost'
  config.port = gateway_port
end

repo = Aptly::Repository.get(REPO_NAME)
snaps = Aptly::Snapshot.list.keep_if { |x| x.Name.start_with?(REPO_NAME) }
raise "bad shots #{snaps}" unless snaps.size == 1
snap = snaps[0]
snap.published_in.each do |pub|
  attributes = pub.to_h
  attributes.delete(:Sources)
  attributes.delete(:SourceKind)
  attributes.delete(:Storage)
  attributes.delete(:Prefix)
  prefix = pub.send(:api_prefix)
  raise 'could not call pub.api_prefix and get a result' unless prefix
  pub.drop
  repo.publish(prefix, attributes)
end
