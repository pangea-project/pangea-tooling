#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2017 Harald Sitter <sitter@kde.org>
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

require 'concurrent'
require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'lib/jenkins/job'
require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/retry'

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: #{$0} 'regex'

Tells jenkins to abort all jobs matching regex

e.g.
  • All build jobs for vivid and utopic:
    '^(vivid|utopic)_.*_.*src'

  • All unstable builds:
    '^.*_unstable_.*src'

  • All jobs:
    '.*src'
  EOS
end.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = File.basename(__FILE__, '.rb')
  l.level = Logger::INFO
end

raise 'Need ruby pattern as argv0' if ARGV.empty?
pattern = Regexp.new(ARGV[0])
@log.info pattern

promises = Jenkins.job.list_all.collect do |name|
  next nil unless pattern.match(name)
  Concurrent::Promise.execute do
    Retry.retry_it(times: 4, sleep: 1) do
      # Retry as Jenkins likes to throw timeouts on too many operations.
      job = Jenkins::Job.new(name)
      job.abort
      @log.warn "Aborting #{name}"
    end
  end
end

promises.compact.each(&:wait!)
