#!/usr/bin/env ruby

require 'date'
require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'ci-tooling/lib/retry'

OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_delte.rb 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
retry.

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
  l.progname = 'poll'
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

module Jenkins
  # A Jenkins Job.
  # Gives jobs a class so one can use it like a bloody OOP construct rather than
  # I don't even know what the default api client thing does...
  class Job
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def delete!
      Jenkins.job.delete(@name)
    end

    def wipe!
      Jenkins.job.wipe_out_workspace(@name)
    end
  end
end

BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    job = Jenkins::Job.new(name)
    @log.info "Deleting #{name}"
    begin
      Retry.retry_it(times: 5) do
        job.wipe!
      end
    rescue
      @log.info "Wiping of #{name} failed. Continue without wipe."
    end
    Retry.retry_it(times: 5) do
      @log.info "Deleting #{name}"
      job.delete!
    end
  end
end
