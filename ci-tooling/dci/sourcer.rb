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
require_relative '../lib/kdeify'
require_relative '../lib/ci/generate_langpack_packaging'
require_relative 'lib/setup_repo'
require_relative 'lib/setup_env'

DCI.setup_repo!
DCI.setup_env!

def orig_source(fetcher, restricted_packaging_copy: false)
  tarball = fetcher.fetch('source')
  raise 'Failed to fetch tarball' unless tarball
  sourcer = CI::OrigSourceBuilder.new(release: ENV.fetch('DIST'),
                                      strip_symbols: true,
                                      restricted_packaging_copy: restricted_packaging_copy)
  sourcer.build(tarball.origify)
end

@type = ARGV.fetch(0, nil)

case @type
when 'tarball'
  puts 'Downloading tarball from URL'
  orig_source(CI::URLTarFetcher.new(File.read('source/url').strip))
when 'uscan'
  puts 'Downloading tarball via uscan'
  orig_source(CI::WatchTarFetcher.new('packaging/debian/watch'))
when 'firefox', 'thunderbird', 'icedove'
  puts 'Special case building for firefox'
  dsc = File.read('source/url').strip
  Dir.chdir('build') do
    system("dget -u #{dsc}")
    dir = Dir.glob("#{@type}-*/").first
    FileUtils.ln_s(dir, 'packaging', verbose: true)
    KDEIfy.firefox! if @type == 'firefox'
    KDEIfy.thunderbird! if @type == 'thunderbird'
    Dir.chdir(dir) do
      args = [
        'dpkg-buildpackage',
        '-us', '-uc', # Do not sign .dsc / .changes
        '-S', # Only build source
        '-d' # Do not enforce build-depends
      ]
      raise 'Could not run dpkg-buildpackage!' unless system(*args)
    end
    FileUtils.rm_rf(dir)
    FileUtils.rm('packaging')
  end
when 'kde-l10n'
  lang = ARGV.fetch(1, nil)
  raise 'No lang specified' unless lang
  puts 'KDE L10N generation mode'
  Dir.chdir('packaging') do
    CI::LangPack.generate_packaging!(lang)
  end
  orig_source(CI::WatchTarFetcher.new('packaging/debian/watch'))
else
  puts 'Unspecified source type, defaulting to VCS build...'
  builder = CI::VcsSourceBuilder.new(release: ENV.fetch('DIST'),
                                     strip_symbols: true)
  builder.run
end
