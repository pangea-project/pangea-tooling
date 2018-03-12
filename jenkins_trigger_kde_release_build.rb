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

require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/retry'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'lib/kdeproject_component'

release = nil

OptionParser.new do |opts|
  opts.banner = <<-END_OF_HELP
Triggers the watcher jobs for when a new release of Frameworks/Plasma/Applications is made.

Usage: jenkins_trigger_new_release_build.rb -r [plasma,applications,frameworks]
  END_OF_HELP

  opts.on('-r TYPE', '--release=TYPE', 'Which release is new') do |r|
    release = r
  end
end.parse!

releases = %w[plasma applications frameworks]

unless releases.include? release
  puts '-r TYPE must be one of plasma, applications, frameworks'
  exit
end

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'trigger_kde_release_build'
  l.level = Logger::INFO
end

packages = KDEProjectsComponent.public_send(release)

job_name_queue = Queue.new
packages.each do |x|
  job_name_queue << "watcher_release_kde_#{x}"
end

@log.info 'Setting system into maintenance mode.'
Jenkins.system.quiet_down

BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    Retry.retry_it(times: 5) do
      status = Jenkins.job.status(name)
      queued = Jenkins.client.queue.list.include?(name)
      @log.info "#{name} | status - #{status} | queued - #{queued}"
      next if Jenkins.client.queue.list.include?(name)

      unless @exclusion_states.include?(Jenkins.job.status(name))
        @log.warn "  #{name} --> build"
        Jenkins.job.build(name)
      end
    end
  end
end

@log.unknown "The CI is now in maintenance mode. Don't forget to unpause it!"
