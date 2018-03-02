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

require_relative '../lib/ci/build_source'
require_relative '../lib/ci/orig_source_builder'
require_relative '../lib/ci/tar_fetcher'
require_relative 'lib/settings'
require_relative 'lib/setup_env'
require_relative 'lib/setup_repo'

# NCI specific source wrapper to handle parameterization properly.
module NCISourcer
  class << self
    def sourcer_args
      args = { strip_symbols: true }
      settings = NCI::Settings.for_job
      sourcer_settings = settings.fetch('sourcer', {})
      restrict = sourcer_settings.fetch('restricted_packaging_copy',
                                        nil)
      return args unless restrict
      args[:restricted_packaging_copy] = restrict
      args
    end

    def orig_source(fetcher)
      tarball = fetcher.fetch('source')
      raise 'Failed to fetch tarball' unless tarball
      sourcer = CI::OrigSourceBuilder.new(**sourcer_args)
      sourcer.build(tarball.origify)
    end

    def run(type = ARGV.fetch(0, nil))
      meths = {
        'tarball' => method(:run_tarball),
        'uscan' => method(:run_uscan),
        'debscm' => method(:run_debscm)
      }
      meth = meths.fetch(type, method(:run_fallback))
      meth.call
    end

    private

    def run_debscm
      puts 'Using tarball from debscm'
      orig_source(CI::DebSCMFetcher.new)
    end

    def run_tarball
      puts 'Downloading tarball from URL'
      orig_source(CI::URLTarFetcher.new(File.read('source/url').strip))
    end

    def run_uscan
      puts 'Downloading tarball via uscan'
      orig_source(CI::WatchTarFetcher.new('packaging/debian/watch',
                                          series: NCI.series.keys,
                                          mangle_download: true))
    end

    def run_fallback
      puts 'Unspecified source type, defaulting to VCS build...'
      builder = CI::VcsSourceBuilder.new(release: ENV.fetch('DIST'),
                                         **sourcer_args)
      builder.run
    end
  end
end

# :nocov:
if $PROGRAM_NAME == __FILE__
  ENV['RELEASEME_PROJECTS_API'] = '1'
  NCI.setup_repo!(with_source: true)
  NCI.setup_env!
  NCISourcer.run
end
# :nocov:
