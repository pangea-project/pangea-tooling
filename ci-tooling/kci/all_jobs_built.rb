#!/usr/bin/env ruby

Dir.chdir('/tmp/') # Containers by default have a bugged out pwd, force /tmp.

require 'logger'
require 'logger/colors'

require_relative 'lib/jenkins'
require_relative 'lib/retry'
require_relative 'lib/thread_pool'

QUALIFIER_STATES = %w(success unstable)

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'all_jobs_built'
  l.level = Logger::INFO
end

def abort(name)
  @log.fatal "  #{name} does not qualify for snapshot. Aborting."
  exit 1
end

dist = ENV.fetch('DIST')
type = ENV.fetch('TYPE')

@log.unknown 'Checking if all relevant jobs are built.'
job_name_queue = Queue.new(Jenkins.job.list("^#{dist}_#{type}_.*"))
all_relevant_jobs_queue = Queue.new

# Gather up all upstreams and build a super-list of the jobs we want and
# their upstreams.
@log.unknown 'Getting jobs and their upstreams.'
BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    Retry.retry_it(times: 5) do
      upstreams = Jenkins.job.get_upstream_projects(name)
      upstreams.each { |u| all_relevant_jobs_queue << u['name'] }
      all_relevant_jobs_queue << name
    end
  end
end

# Filter out mgmt clutter, duplicates etc.
@log.unknown 'Filtering relevant jobs.'
relevant_jobs = all_relevant_jobs_queue.to_a
relevant_jobs.reject! do |j|
  next true if j.start_with?('mgmt_')
  next true if j.start_with?('merger_')
  false
end
relevant_jobs.compact!
relevant_jobs.uniq!
relevant_jobs_queue = Queue.new(relevant_jobs)

# Check status of the jobs through a very simply threaded queue.
# This allows $threadcount concurrent connections which is heaps
# faster than doing this sequentially. In particular when run
# outside localhost.
@log.unknown 'Checking job status.'
BlockingThreadPool.run do
  until relevant_jobs_queue.empty?
    name = relevant_jobs_queue.pop(true)
    Retry.retry_it(times: 5) do
      status = Jenkins.job.status(name)
      queued = Jenkins.client.queue.list.include?(name)
      @log.info "#{name} | status - #{status} | queued - #{queued}"
      abort(name) unless QUALIFIER_STATES.include?(Jenkins.job.status(name))
      abort(name) if Jenkins.client.queue.list.include?(name)
    end
  end
end

@log.unknown '-----------------------done-----------------------'
exit 0
