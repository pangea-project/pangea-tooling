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

require_relative 'lib/jenkins'
require_relative 'lib/retry'
require_relative 'lib/thread_pool'
require_relative 'lib/kdeproject_component'
require_relative 'lib/nci'

@series
@edition
@component
@exclusion_states = %w[success unstable]
strict_mode = false

# This block is very long because it is essentially a DSL.
# rubocop:disable Metrics/BlockLength
OptionParser.new do |opts|
  opts.banner = <<-SUMMARY
Usage: jenkins_retry_builds.rb [options]
Requires a single option from Series & Edition & Component
  jenkins_retry_builds.rb --future --unstable --plasma
  jenkins_retry_builds.rb -2 -C -p
Single option can be added from multiple available Build States
jenkins_retry_builds.rb --future --unstable --plasma --strict
jenkins_retry_builds.rb -2 -C -p -s
  SUMMARY

  ## Series
  opts.on('-1', '--current', 'current_series') do
    @series = NCI.current_series
  end
  opts.on('-2', '--future', 'future_series') do
    @series = NCI.future_series
  end
  opts.on('-3', '--old', 'old_series') do
    @series = NCI.old_series
  end

  ## Edition
  opts.on('-A', '--user', 'user edition') do
    @edition = "release"
  end
  opts.on('-B', '--stable', 'stable edition') do
    @edition = "stable"
  end
  opts.on('-C', '--unstable', 'unstable edition') do
    @edition = "unstable"
  end
  opts.on('-D', '--all_editions', 'all editions') do
    @edition = "[^_]+"
  end

  ## Component
  opts.on('-f', '--frameworks', 'kf5_component') do
    kf5_component = KDEProjectsComponent.frameworks_jobs
    @component = kf5_component
  end
  opts.on('-w', '--frameworks6', 'kf6_component') do
    kf6_component = KDEProjectsComponent.kf6_jobs
    @component = kf6_component
  end
  opts.on('-g', '--gear', 'gear_component.') do
    gear_component = KDEProjectsComponent.gear_jobs
    @component = gear_component
  end
  opts.on('-n', '--maui', 'maui_component') do
    maui_component = KDEProjectsComponent.maui_jobs
    @component = maui_component
  end
  opts.on('-m', '--mobile', 'mobile_component') do
    mobile_component = KDEProjectsComponent.mobile_jobs
    @component = mobile_component
  end
  opts.on('-q', '--pim', 'pim_component') do
    pim_component = KDEProjectsComponent.pim_jobs
    @component = pim_component
  end
  opts.on('-p', '--plasma', 'plasma_component') do
    plasma_component = KDEProjectsComponent.plasma_jobs
    @component = plasma_component
  end

  ## Build States
  opts.on('-b', '--build', 'Rebuild even if job did not fail.') do
    @exclusion_states.clear
  end
  opts.on('-u', '--unstable_jobs', 'Rebuild unstable jobs as well.') do
    @exclusion_states.delete('unstable')
  end
  opts.on('-s', '--strict', 'Build jobs whose downstream jobs have failed') do
    @exclusion_states.clear
    strict_mode = true
  end
end.parse!
# rubocop:enable Metrics/BlockLength


@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'jenkins_retry_builds'
  l.level = Logger::INFO
end

p "series = #{@series}"
p "edition = #{@edition}"
p "components = #{@component}"

pattern = nil

if @component
  pattern = Regexp.new("#{@series}_#{@edition}_[^_]+_(#{@component.join('|')})$")
else
  raise 'Requires at least an option from Series & Edition & Component' if ARGV.empty?

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

BlockingThreadPool.run(2) do
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
