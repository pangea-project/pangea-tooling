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

# Aborts jobs, if that fails it terms them, if that fails it kills them.
class JobsAborter
  attr_reader :pattern
  attr_reader :builds

  def initialize(pattern)
    @log = Logger.new(STDOUT).tap do |l|
      l.progname = File.basename(__FILE__, '.rb')
      l.level = Logger::INFO
    end
    @log.info pattern
    @pattern = pattern
    @builds = initial_builds
  end

  def run
    if builds.empty?
      @log.info 'Nothing building'
      return
    end
    murder
  end

  private

  def murder
    stab_them(:abort)
    return if done?

    query_continue?('abort', 'term')
    stab_them(:term)
    return if done?

    query_continue?('term', 'kill')
    stab_them(:kill)
    return if done?

    query_continue?('kill', 'give up')
  end

  def query_continue?(failed_action, new_action)
    loop do
      puts <<-MSG
--------------------------------------------------------------------------------
#{builds.keys.join($/)}
These jobs did not #{failed_action} in time, do you want to #{new_action}? [y/n]
      MSG
      answer = STDIN.gets.chop.downcase
      raise 'aborting murder sequence' if answer == 'n'
      break if answer == 'y'
    end
  end

  def initial_builds
    jobs = Jenkins.job.list_all.select { |name| pattern.match(name) }
    builds = jobs.map do |name|
      job = Jenkins::Job.new(name)
      current = job.current_build_number
      next nil unless current && job.building?(current)
      [job, current]
    end
    builds.compact.to_h
  end

  def reduce_builds
    @builds = builds.select do |job, build|
      job.current_build_number == build && job.building?(build)
    end
  end

  def stab_them(action)
    promises = builds.collect do |job, number|
      Concurrent::Promise.execute do
        Retry.retry_it(times: 4, sleep: 1) do
          @log.warn "#{action} -> #{job}"
          # Retry as Jenkins likes to throw timeouts on too many operations.
          # NB: this needs public send, else we'd call process abort!
          job.public_send(action, number.to_s)
        end
      end
    end
    promises.compact.each(&:wait!)
  end

  def done?
    sleep 16
    reduce_builds
    builds.empty?
  end
end

OptionParser.new do |opts|
  opts.banner = <<-HELP_BANNER
Usage: #{$0} 'regex'

Tells jenkins to abort all jobs matching regex

e.g.
  • All build jobs for vivid and utopic:
    '^(vivid|utopic)_.*_.*src'

  • All unstable builds:
    '^.*_unstable_.*src'

  • All jobs:
    '.*src'
  HELP_BANNER
end.parse!

raise 'Need ruby pattern as argv0' if ARGV.empty?
pattern = Regexp.new(ARGV[0])

JobsAborter.new(pattern).run
