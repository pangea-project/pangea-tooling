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

require 'date'
require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'ci-tooling/lib/retry'
require_relative 'lib/jenkins/job'

enable = false

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_able.rb [options] 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

e.g.
  • All build jobs for vivid and utopic:
    '^(vivid|utopic)_.*_.*'

  • All unstable builds:
    '^.*_unstable_.*'

  • All jobs:
    '.*'
  EOS

  opts.on('-e', '--enable', 'Enable jobs matching the pattern') do
    enable = true
  end

  opts.on('-d', '--disable', 'Disable jobs matching the pattern') do
    enable = false
  end
end.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'able'
  l.level = Logger::INFO
end

raise 'Need ruby pattern as argv0' if ARGV.empty?
pattern = Regexp.new(ARGV[0])
@log.info pattern

job_names = Jenkins.job.list_all.select { |name| pattern.match(name) }
job_names.each do |job_name|
  job = Jenkins::Job.new(job_name)
  if enable
    @log.info "Enabling #{job_name}"
    job.enable!
  else
    @log.info "Disabling #{job_name}"
    job.disable!
  end
end
