require 'logger'
require 'logger/colors'

require_relative 'ci-tooling/lib/jenkins'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'ci-tooling/lib/retry'

QUALIFIER_STATES = %w(success unstable)

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
        @log.warn '  --> build'
        Jenkins.job.build(name)
      end
    end
  end
end
