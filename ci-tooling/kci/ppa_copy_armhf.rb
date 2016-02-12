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
require_relative 'lib/thread_pool'

class PPAString
  class Error < Exception; end
  class ParseError < Error; end
  class PrefixError < ParseError; end

  attr_reader :team
  attr_reader :name

  def initialize(string)
    unless string.start_with?('ppa:')
      raise PrefixError, 'No valid ppa identifier, needs to start with ppa:'
    end
    ppa_name = string.split('ppa:').last
    @team, @name = ppa_name.split('/')
  end
end

THREAD_COUNT = 9

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options] ppa:PPA_IDENTIFIER"

  opts.on('-s SERIES', '--series SERIES',
          'Ubuntu series to run on (or nil for all)') do |v|
    options[:series] = v
  end
end.parse!

raise 'Less than two ppa identifier given' if ARGV.size < 2
raise 'More than two ppa identifier given' if ARGV.size > 2
origin = PPAString.new(ARGV.shift)
target = PPAString.new(ARGV.pop)

Launchpad.authenticate
origin_ppa = Launchpad::Rubber.from_path("~#{origin.team}/+archive/ubuntu/#{origin.name}")
target_ppa = Launchpad::Rubber.from_path("~#{target.team}/+archive/ubuntu/#{target.name}")

sources = []
if options[:series]
  series = Launchpad::Rubber.from_path("ubuntu/#{options[:series]}")
  sources = origin_ppa.getPublishedSources(status: 'Published',
                                           distro_series: series)
else
  sources = origin_ppa.getPublishedSources(status: 'Published')
end

source_queue = Queue.new(sources)
sources_to_copy_queue = Queue.new
BlockingThreadPool.run do
  until source_queue.empty?
    source = source_queue.pop(true)
    has_arm = false
    source.getBuilds.each do |build|
      has_arm = true && break if build.arch_tag == 'armhf'
    end
    next unless has_arm

    sources_to_copy_queue << source
  end
end

BlockingThreadPool.run do
  log = Logger.new(STDOUT)
  log.level = Logger::INFO
  log.datetime_format = ''
  until sources_to_copy_queue.empty?
    source = sources_to_copy_queue.pop(true)
    log.info "Copying #{source.source_package_name} to #{target_ppa.name}"
    target_ppa.copyPackage!(from_archive: origin_ppa,
                            source_name: source.source_package_name,
                            version: source.source_package_version,
                            to_pocket: 'Release',
                            include_binaries: true)
  end
end
