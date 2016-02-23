#!/usr/bin/env ruby

require 'logger'
require 'logger/colors'
require 'optparse'

require_relative '../lib/kci'
require_relative 'lib/lp'
require_relative 'lib/retry'
require_relative 'lib/thread_pool'

THREAD_COUNT = 8

LOG = Logger.new(STDERR)
LOG.level = Logger::INFO
LOG.progname = File.basename($PROGRAM_NAME)
LOG.warn 'PPA Promote'

options = OpenStruct.new(series: nil, ppa: nil)
parser = OptionParser.new do |opts|
  opts.on('-s SERIES', '--series SERIES', 'Ubuntu series to run on') do |v|
    options[:series] = v
  end
end
parser.parse!

abort parser.help if options[:series].nil?

# A PPA.
class Archive
  attr_accessor :ppa

  def initialize(name, series)
    @ppa = Launchpad::Rubber.from_path("~kubuntu-ci/+archive/ubuntu/#{name}")
    @series = Launchpad::Rubber.from_path("ubuntu/#{series}")
  end

  def wipe
    # We need to iter clear as Deleted entries would still retain their entry
    # making the unfiltered list grow larger and larger every time.
    %i(Pending Published Superseded Obsolete).each do |status|
      sources = @ppa.getPublishedSources(status: status, distro_series: @series)
      source_queue = Queue.new(sources)
      BlockingThreadPool.run(THREAD_COUNT) do
        until source_queue.empty?
          source = source_queue.pop(true)
          Retry.retry_it do
            LOG.info "Requesting deletion of: #{source.display_name}" \
            " from #{@ppa.name}"
            source.requestDeletion!
          end
        end
      end
    end
  end
end

Launchpad.authenticate

KCI.types.each do |type|
  LOG.info "Working on #{type}"
  Archive.new(type.to_s, options.series).wipe
  %w(daily weekly).each do |snapshot|
    LOG.info "Working on #{type}-#{snapshot}"
    Archive.new("#{type}-#{snapshot}", options.series).wipe
  end
end

exit 0
