#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2016 Rohan Garg <rohan@kde.org>
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

require_relative '../lib/ci/build_source'
require_relative '../lib/ci/orig_source_builder'
require_relative '../lib/ci/tar_fetcher'
require_relative 'lib/setup_repo'

DCI.setup_repo!

def orig_source(fetcher)
  tarball = fetcher.fetch('source')
  raise 'Failed to fetch tarball' unless tarball
  sourcer = CI::OrigSourceBuilder.new(release: ENV.fetch('DIST'),
                                      strip_symbols: true)
  sourcer.build(tarball.origify)
end

case ARGV.fetch(0, nil)
when 'tarball'
  puts 'Downloading tarball from URL'
  orig_source(CI::URLTarFetcher.new(File.read('source/url').strip))
when 'uscan'
  puts 'Downloading tarball via uscan'
  orig_source(CI::WatchTarFetcher.new('packaging/debian/watch'))
else
  puts 'Unspecified source type, defaulting to VCS build...'
  builder = CI::VcsSourceBuilder.new(release: ENV.fetch('DIST'),
                                     strip_symbols: true)
  builder.run
end
