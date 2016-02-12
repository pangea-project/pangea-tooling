#!/usr/bin/env ruby
#
# Copyright (C) 2015 Harald Sitter <sitter@kde.org>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License or (at your option) version 3 or any later version
# accepted by the membership of KDE e.V. (or its successor approved
# by the membership of KDE e.V.), which shall act as a proxy
# defined in Section 14 of version 3 of the license.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'logger'
require 'logger/colors'
require 'optparse'
require 'thwait'

require_relative 'lib/lp'

THREAD_COUNT = 9

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] ppa:PPA_IDENTIFIER"

  opts.on('-s SERIES', '--series SERIES',
          'Ubuntu series to run on (or nil for all)')  do |v|
    options[:series] = v
  end
end.parse!

raise 'More than one ppa identifier given' if ARGV.size > 1
ppa_name = ARGV.pop
raise 'No valid ppa identifier' unless ppa_name.start_with?('ppa:')
ppa_name = ppa_name.split('ppa:').last
ppa_team, ppa_name = ppa_name.split('/')

Launchpad.authenticate
ppa = Launchpad::Rubber.from_path("#{ppa_team}/+archive/ubuntu/#{ppa_name}")

sources = []
if options[:series]
  series = Launchpad::Rubber.from_path("ubuntu/#{options[:series]}")
  sources = ppa.getPublishedSources(status: 'Published', distro_series: series)
else
  sources = ppa.getPublishedSources(status: 'Published')
end

source_queue = Queue.new
sources.each { |s| source_queue << s }

threads = []
THREAD_COUNT.times do |i|
  threads << Thread.new do
    log = Logger.new(STDOUT)
    log.progname = "t-#{i}"
    log.level = Logger::INFO
    log.datetime_format = ''

    while source = source_queue.pop(true)
      begin
        log.info "Retrying #{source.display_name}"
        source.getBuilds.each do |b|
          next if b.buildstate == 'Successfully built'
          begin
            b.retry!
          rescue => e
            log.warn "Caught exception on retry... #{e}"
            retry
          end
        end
      rescue => e
        log.warn "Caught exception #{e}"
        retry
      end
    end
  end
end
ThreadsWait.all_waits(threads)
