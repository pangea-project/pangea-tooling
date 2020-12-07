#!/usr/bin/env ruby
# coding: utf-8
# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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
require 'tty/prompt'
require 'tty/spinner'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/retry'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'lib/kdeproject_component'
require_relative 'ci-tooling/lib/nci'

@exclusion_states = %w[success unstable]
strict_mode = false
new_release = nil
pim_release = nil

# This block is very long because it is essentially a DSL.
# rubocop:disable Metrics/BlockLength
OptionParser.new do |opts|
  opts.banner = <<-SUMMARY
Usage: jenkins_retry.rb [options] 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

Only jobs that are not queued, not building, and failed will be retired.
  e.g.
    • All build jobs for vivid and utopic:
      '^(vivid|utopic)_.*_.*'
    • All unstable builds:
      '^.*_unstable_.*'
    • All neon kde releases
      'focal_release_[^_]+_[^_]+$'
    • All jobs:
      '.*'

  SUMMARY

  opts.on('-p', '--plasma', 'There has been a new Plasma release, run all' \
                            ' watcher jobs for Plasma.') do
    @exclusion_states.clear
    new_release = KDEProjectsComponent.plasma_jobs
  end

  opts.on('-r', '--releases', 'There has been new Release Service releases,' \
                                  ' run all watcher jobs for them.') do
    @exclusion_states.clear
    new_release = KDEProjectsComponent.release_service_jobs
  end

  opts.on('-f', '--frameworks', 'There has been a new Frameworks release, run' \
                                ' all watcher jobs for Frameworks.') do
    @exclusion_states.clear
    new_release = KDEProjectsComponent.frameworks_jobs
  end

  opts.on('--pim', 'There has been a PIM ABI bump, run' \
                    ' all unstable jobs for PIM.') do
    @exclusion_states.clear
    pim_release = KDEProjectsComponent.pim_jobs
  end

  opts.on('-b', '--build', 'Rebuild even if job did not fail.') do
    @exclusion_states.clear
  end

  opts.on('-u', '--unstable', 'Rebuild unstable jobs as well.') do
    @exclusion_states.delete('unstable')
  end

  opts.on('-s', '--strict', 'Build jobs whose downstream jobs have failed') do
    @exclusion_states.clear
    strict_mode = true
  end
end.parse!
# rubocop:enable Metrics/BlockLength

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'retry'
  l.level = Logger::INFO
end

pattern = nil
if new_release
  pattern = Regexp.new("watcher_release_[^_]+_(#{new_release.join('|')})$")
elsif pim_release
  pattern = Regexp.new("#{NCI.current_series}_stable_kde_(#{pim_release.join('|')})$")
else
  raise 'Need ruby pattern as argv0' if ARGV.empty?
  pattern = Regexp.new(ARGV[0])
end

@log.info pattern

spinner = TTY::Spinner.new('[:spinner] Loading job list', format: :spin_2)
spinner.update(title: 'Loading job list')
spinner.auto_spin
job_name_queue = Queue.new
job_names = Jenkins.job.list_all
spinner.success

job_names.each do |job_name|
  next unless pattern.match(job_name)
  job_name_queue << job_name
end

if job_name_queue.size > 8
  if TTY::Prompt.new.no?("Your are going to retry #{job_name_queue.size} jobs." \
    ' Do you want to continue?')
    abort
  end
elsif job_name_queue.empty?
  abort 'No jobs matched your pattern'
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

      if strict_mode
        skip = true
        downstreams = Jenkins.job.get_downstream_projects(name)
        downstreams << Jenkins.job.list_details(name.gsub(/_src/, '_pub'))
        downstreams.each do |downstream|
          downstream_status = Jenkins.job.status(downstream['name'])
          next if %w[success unstable running].include?(downstream_status)
          skip = false
        end
        @log.info "Skipping #{name}" if skip
        next if skip
      end

      unless @exclusion_states.include?(Jenkins.job.status(name))
        @log.warn "  #{name} --> build"
        Jenkins.job.build(name)
      end
    end
  end
end

@log.unknown "The CI is now in maintenance mode. Don't forget to unpause it!"

unless TTY::Prompt.new.no?('Unpause now? Only when you are sure only useful' \
  ' jobs are being retried.')
  Jenkins.system.cancel_quiet_down
end
