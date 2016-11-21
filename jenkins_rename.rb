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

parser = OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_able.rb [options] 'regex' 'PATTERN' 'SUBPATTERN'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

e.g.
  • Sub 'plasma' in all jobs for 'liquid':
    '.*' plasma liquid
  EOS
end
parser.parse!

if ARGV.size < 3
  warn 'Not enough arguments.'
  warn parser.help
  abort
end

@log = Logger.new(STDOUT).tap do |l|
  l.progname = $PROGRAM_NAME
  l.level = Logger::INFO
end

pattern = Regexp.new(ARGV[0])
from = ARGV[1]
to = ARGV[2]
ARGV.clear
@log.info "Finding all jobs for #{pattern} and renaming using sub #{from} #{to}"

client = JenkinsApi::Client.new
job_names = client.job.list_all.select { |name| pattern.match(name) }

puts "Jobs: \n#{job_names.join("\n")}"
loop do
  puts 'Does that list look okay? (y/n)'
  case gets.strip.downcase
  when 'y' then break
  when 'n' then exit
  end
end

job_names.each do |job_name|
  new_name = job_name.gsub(from, to)
  @log.info "#{job_name} => #{new_name}"
  Jenkins::Job.new(job_name).rename(new_name)
end
