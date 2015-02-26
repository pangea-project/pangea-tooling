#!/usr/bin/env ruby

require 'json'
require 'logger'
require 'ostruct'
require 'net/http'
require 'date'

LOG = Logger.new(STDOUT)
LOG.level = Logger::INFO

job_url = ENV.fetch('JOB_URL')
build_number = ENV.fetch('BUILD_NUMBER').to_i

uri = URI("#{job_url}/api/json?pretty=false&depth=1")
job_json = Net::HTTP.get(uri)
job = JSON.parse(job_json, object_class: OpenStruct)

builds = job.builds
builds.sort_by!(&:number)
builds.reverse!

current_build = nil
current_build_date = nil
out_of_date_range = false
builds = builds.delete_if do |build|
  next true if out_of_date_range
  if build.number > build_number
    next true
  elsif build.number == build_number
    current_build = build
    if !build.actions.empty? && build.actions[0] &&
       !build.actions[0].empty? && build.actions[0].causes[0] &&
       build.actions[0].causes[0].respond_to?(:userId)
      LOG.info 'Current build was manually started by' \
               " #{build.actions[0].causes[0].userId}"
      exit 0
    end
    current_build_date = Date.parse(Time.at(build.timestamp / 1000).to_s)
    next true
  end
  previous_build_date = Date.parse(Time.at(build.timestamp / 1000).to_s)
  out_of_date_range = current_build_date != previous_build_date
end

# builds now only contains builds of the same day as the current build.

abort_results = %w(SUCCESS)
builds.each do |build|
  if abort_results.include?(build.result)
    LOG.info "Had a good build today, aborting: #{build.id} - #{build.result}"
    exit 1
  end
end

# We encountered no build that was successful or at least unstable today, so
# let's go ahead and return with success so that we may attempt a new build.

LOG.info 'Attempting a build!'
exit 0
