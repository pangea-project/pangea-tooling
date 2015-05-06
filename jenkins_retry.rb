#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/retry'
require_relative 'ci-tooling/lib/thread_pool'

QUALIFIER_STATES = %w(success unstable)

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_retry.rb 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

Only jobs that are not queued, not building, and failed will be retired.

e.g.
  • All build jobs for vivid and utopic:
    '^(vivid|utopic)_.*_.*'

  • All unstable builds:
    '^.*_unstable_.*'

  • All jobs:
    '.*'
  EOS
end.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'retry'
  l.level = Logger::INFO
end

fail 'Need ruby pattern as argv0' if ARGV.empty?
pattern = Regexp.new(ARGV[0])
@log.info pattern

job_name_queue = Queue.new
job_names = Jenkins.job.list_all
job_names.each do |name|
  next unless pattern.match(name)
  job_name_queue << name
end

BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    Retry.retry_it(times: 5) do
      status = Jenkins.job.status(name)
      queued = Jenkins.client.queue.list.include?(name)
      @log.info "#{name} | status - #{status} | queued - #{queued}"
      next if Jenkins.client.queue.list.include?(name)
      unless QUALIFIER_STATES.include?(Jenkins.job.status(name))
        @log.warn "  #{name} --> build"
        Jenkins.job.build(name)
      end
    end
  end
end
