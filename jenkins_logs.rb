#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true
#
# Copyright (C) 2019 Harald Sitter <sitter@kde.org>
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

require 'optparse'
require 'tty/pager'
require 'tty/prompt'
require 'tty/spinner'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/ci/pattern'
require_relative 'lib/jenkins/job'

@grep_pattern = nil

# This block is very long because it is essentially a DSL.
OptionParser.new do |opts|
  opts.banner = <<-SUMMARY
Streams all build of failed logs to STDOUT. Note that this is potentially a lot
of data, so use a smart regex and possibly run it on the master server.

Usage: #{opts.program_name} [options] 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry. See jenkins_retry for examples.
  SUMMARY

  opts.on('--grep PATTERN', 'Greps all logs for (posix) pattern [eats RAM!]') do |v|
    v.prepend('*') unless v[0] == '*'
    v += '*' unless v[-1] == '*'
    @grep_pattern = CI::FNMatchPattern.new(v)
  end
end.parse!

pattern = nil
raise 'Need ruby pattern as argv0' if ARGV.empty?

pattern = Regexp.new(ARGV[0])

spinner = TTY::Spinner.new('[:spinner] :title', format: :spin_2)
spinner.update(title: 'Loading job list')
spinner.auto_spin
job_names = Jenkins.job.list_by_status('failure')
spinner.success

job_names = job_names.select do |job_name|
  next false unless pattern.match(job_name)

  true
end

if job_names.size > 8
  if TTY::Prompt.new.no?("Your are going to check #{job_names.size} jobs." \
    ' Do you want to continue?')
    abort
  end
elsif job_names.empty?
  abort 'No jobs matched your pattern'
end

# Wrapper around a joblog so output only needs fetching once
class JobLog
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def output
    @output ||= begin
      spinner = TTY::Spinner.new('[:spinner] :title', format: :spin_2)
      spinner.update(title: "Download console of #{name}")
      spinner.auto_spin
      text = read
      spinner.success
      text
    end
  end

  def to_s
    name
  end

  private

  def job
    @job ||= Jenkins::Job.new(name)
  end

  def read
    text = ''
    offset = 0
    loop do
      output = job.console_output(job.build_number)
      text += output.fetch('output')
      break unless output.fetch('more')

      offset += output.fetch('size') # stream next part
      sleep 5
    end
    text
  end
end

logs = job_names.collect { |name| JobLog.new(name) }
if @grep_pattern
  logs.select! do |log|
    @grep_pattern.match?(log.output)
  end
end

abort 'No matching logs found :(' if logs.empty?

# group_by would make the value an array, since names are unique we don't need that though
logs = logs.map { |log| [log.name, log] }.to_h

prompt = TTY::Prompt.new
loop do
  selection = prompt.select('Select job or hit ctrl-c to exit',
                            logs.keys,
                            per_page: 32, filter: true)

  log = logs.fetch(selection)
  pager = TTY::Pager.new
  pager.page(log.output)
end
