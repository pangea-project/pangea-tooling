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
require 'thwait'

require_relative 'lib/lp'

distribution = 'utopic'
# to_copy = ARGV

fail 'need dist arg' if ARGV.empty?
# distribution = ARGV[0]

# to_copy = %x[ssh git.debian.org ls /git/pkg-kde/frameworks]
# to_copy.chop!.gsub!('.git', '').split(' ')

Launchpad.authenticate
# FIXME: current assumptions: source is unstable, target is always stable
ppa_base = '~kubuntu-ci/+archive/ubuntu'
source_ppa = Launchpad::Rubber.from_path("#{ppa_base}/#{ARGV[0]}")
target_ppa = Launchpad::Rubber.from_path("#{ppa_base}/unstable-weekly")
series = Launchpad::Rubber.from_path("ubuntu/#{distribution}")

sources = source_ppa.getPublishedSources(status: 'Published',
                                         distro_series: series)

source_queue = Queue.new
sources.each { |s| source_queue << s }

threads = []
9.times do |i|
  threads << Thread.new do
    log = Logger.new(STDOUT)
    log.progname = "t-#{i}"
    log.level = Logger::INFO
    log.datetime_format = ''

    while (s = source_queue.pop(true))
      begin
        unless target_ppa.getPublishedSources(distro_series: series,
                                              source_name:
                                                s.source_package_name,
                                              version: s.source_package_version,
                                              exact_match: true).empty?
          log.warn "Skipping #{s.display_name}; already there"
          next
        end
        log.info "Copying #{s.display_name}"
        target_ppa.copyPackage!(from_archive: source_ppa,
                                source_name: s.source_package_name,
                                version: s.source_package_version,
                                to_pocket: 'Release',
                                include_binaries: true)
      rescue => e
        log.warn "Caught exception #{e}"
        retry
      end
    end
  end
end
ThreadsWait.all_waits(threads)
