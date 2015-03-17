#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'

require_relative '../ci-tooling/lib/jenkins/daily_run'

@log = Logger.new(STDOUT)
@log.level = Logger::INFO

job = Jenkins::DailyRun.new

if job.manually_triggered?
  @log.info 'Current build was manually started'
  exit 0
end

if job.ran_today?
  @log.info 'Had a good build today, aborting'
  exit 1
end

# We encountered no build that was successful or at least unstable today, so
# let's go ahead and return with success so that we may attempt a new build.

@log.info 'Attempting a build!'
exit 0
