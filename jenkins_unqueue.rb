#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'
require 'optparse'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/retry'
require_relative 'ci-tooling/lib/thread_pool'

parser = OptionParser.new do |opts|
  opts.banner = <<-EOS
Usage: jenkins_unqueue.rb 'regex'

regex must be a valid Ruby regular expression matching the jobs you wish to
unqueue.

Only jobs that queued can be removed from the queue (obviously)
  e.g.
    • All build jobs for vivid and utopic:
      '^(vivid|utopic)_.*_.*'
    • All unstable builds:
      '^.*_unstable_.*'
    • All jobs:
      '.*'

  EOS
end
parser.parse!

@log = Logger.new(STDOUT).tap do |l|
  l.progname = 'retry'
  l.level = Logger::INFO
end

abort parser.help if ARGV.empty?
pattern = Regexp.new(ARGV[0])
@log.info pattern

job_name_queue = Queue.new
job_names = Jenkins.client.queue.list
job_names.each do |name|
  next unless pattern.match(name)
  job_name_queue << name
end

BlockingThreadPool.run do
  until job_name_queue.empty?
    name = job_name_queue.pop(true)
    Retry.retry_it(times: 5) do
      id = Jenkins.client.queue.get_id(name)
      @log.info "unqueueing #{name} (#{id})"
      Jenkins.client.api_post_request('/queue/cancelItem', id: id)
    end
  end
end
