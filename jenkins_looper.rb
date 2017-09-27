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
require_relative 'ci-tooling/lib/thread_pool'

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: #{$0} [options] name

Finds depenendency loops by traversing the upstreams of name looking for another
appearance of name. This is handy if a job is stuck waiting on itself but it's
not clear where the loop is.
  EOS
end.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = File.basename($0)
  l.level = Logger::INFO
end

raise 'Need name as argv0' if ARGV.empty?
name = ARGV[0]
@log.info name

# Looks for loops
class Walker
  # Looping error
  class LoopError < RuntimeError
    def prepend(job)
      set_backtrace("#{job} -> #{backtrace.join}")
    end
  end

  def initialize(name, log)
    @job = Jenkins::Job.new(name)
    @log = log
    @known = {}
    @seen = []
  end

  def walk!
    require 'pp'
    know!(@job)
    @log.warn 'everything is known'
    find_loop(@job.name)
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  # This would be a separate class, anything else we'd have to pass our state
  # vars through, so simply accept this method beng a bit complicated.
  def find_loop(name, orig = name, root: true, depth: 1)
    puts "#{Array.new(depth * 2, ' ').join}#{name}"
    @known[name].each do |up|
      next if @seen.include?(up)
      if up == orig && !root
        error = LoopError.new('loop found')
        error.set_backtrace(up.to_s)
        raise error
      end
      find_loop(up, orig, root: false, depth: depth + 1)
      @seen << up
    end
  rescue LoopError => e
    e.prepend(name)
    raise e
  end

  def know!(job)
    return if @known.include?(job.name)
    @known[job.name] ||= job.upstream_projects.collect { |x| x.fetch('name') }
    @known[job.name].each { |x| know!(Jenkins::Job.new(x)) }
  end
end

Walker.new(name, @log).walk!
