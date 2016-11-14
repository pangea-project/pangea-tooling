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

module Aptly
  # Configuration.
  class Configuration
    def uri
      # FIXME: maybe we should simply configure a URI instead of configuring
      #   each part?
      uri = URI.parse('')
      uri.scheme = 'https'
      uri.host = host
      uri.port = port
      uri.path = path
      uri
    end
  end
end

Aptly.configure do |c|
  # Meant to be run on archive host.
  c.host = 'archive-api.neon.kde.org'
  c.port = 443
end

stamp = Time.now.utc.strftime('%Y%m%d.%H%M')
release = Aptly::Repository.get('release_xenial')
snapshot = release.snapshot(Name: "release_xenial-#{stamp}")
# Limit to user for now.
pubs = Aptly::PublishedRepository.list.select do |x|
  x.Prefix == 'user' && x.Distribution == 'xenial'
end
pub = pubs[0]
pub.update!(Snapshots: [{ Name: snapshot.Name, Component: 'main' }])

published_snapshots = Aptly::PublishedRepository.list.select do |x|
  x.SourceKind == 'snapshot'
end
published_snapshots = published_snapshots.map(&:Sources).flatten.map(&:Name)
puts "Currently published snapshots: #{published_snapshots}"

snapshots = Aptly::Snapshot.list.select do |x|
  x.Name.start_with?(release.Name)
end
puts "Available snapshots: #{snapshots.map(&:Name)}"

dangling_snapshots = snapshots.reject do |x|
  published_snapshots.include?(x.Name)
end
dangling_snapshots.each do |x|
  x.CreatedAt = DateTime.parse(x.CreatedAt)
end
dangling_snapshots.sort_by!(&:CreatedAt)
dangling_snapshots.pop # Pop newest dangle as a backup.
puts "Dangling snapshots: #{dangling_snapshots.map(&:Name)}"
dangling_snapshots.each(&:delete)
puts 'Dangling snapshots deleted'
