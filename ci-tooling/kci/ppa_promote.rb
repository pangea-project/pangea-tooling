#!/usr/bin/env ruby

require 'date'
require 'json'
require 'logger'
require 'logger/colors'

require_relative 'lib/lp'
require_relative 'lib/thread_pool'
require_relative 'lib/retry'

# Launchpad has a race condition on copying packages, until it is resolved we
# can not thread or we would need to atomically check if all things end up in
# the target repo and if not, do another copy after 20 minutes.
# Since waiting 20 and then doing it again would be slower than just copying one
# by one we instead do that by limiting our thread pool.
# https://bugs.launchpad.net/launchpad/+bug/1314569
THREAD_COUNT = 8
# Wiping is unaffected as far as we can tell.
WIPE_THREAD_COUNT = 8
# Polling isn't either.
POLL_THREAD_COUNT = WIPE_THREAD_COUNT

LOG = Logger.new(STDERR)
LOG.level = Logger::INFO
LOG.progname = 'ppa_promote'
LOG.warn 'PPA Promote'

Project = Struct.new(:series, :type)
project = Project.new(ENV.fetch('DIST'), ENV.fetch('TYPE'))

# Helpers for verifying a PPA.
module VerifablePPA
  EXISTING_STATES = %w(Pending Published).freeze

  # @param packages [Hash<String, String>] Hash of package-versions
  # @return [Array<String>] array of source names that are existing
  def existing_sources(packages)
    source_queue = Queue.new(packages.to_a)
    exist_queue = Queue.new
    BlockingThreadPool.run(POLL_THREAD_COUNT) do
      until source_queue.empty?
        entry = source_queue.pop(true)
        exist_queue << entry[0] if source_exist?(*entry)
      end
    end
    exist_queue.to_a
  end

  def source_exist?(name, version)
    sources = getPublishedSources(source_name: name, version: version,
                                  exact_match: true)
    sources.reject! { |s| !EXISTING_STATES.include?(s.status) }
    return true if sources.size == 1
    if sources.size > 1
      LOG.error "Found more than one matching source for #{name}=#{version}"
      LOG.error sources
      raise "Found more than one matching source for #{name}=#{version}"
    end
    false
  end
end

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
      sources = @ppa.getPublishedSources(status: status,
                                         distro_series: @series,
                                         exact_match: true)
      source_queue = Queue.new(sources)
      BlockingThreadPool.run(WIPE_THREAD_COUNT) do
        until source_queue.empty?
          source = source_queue.pop(true)
          next if source.status == 'Deleted'
          Retry.retry_it do
            LOG.info "Requesting deletion of: #{source.source_package_name} " \
                     " from #{@ppa.name}"
            source.requestDeletion!
          end
        end
      end
    end
  end

  def copy(packages, from_ppa)
    # We are modifying, dup it first.
    packages = packages.dup
    make_ppa_verifable!
    Retry.retry_it(times: 10, sleep: (60 * 5)) do
      copy_internal(packages, from_ppa)
      existing_sources = @ppa.existing_sources(packages)
      packages.reject! do |p|
        next true if existing_sources.include?(p)
        LOG.warn "Package #{p} hasn't been copied. Going to try again shortly."
        false
      end
      unless packages.empty?
        raise "Not all packages copied successfully #{packages}"
      end
    end
  end

  private

  def make_ppa_verifable!
    eigenclass = (class << @ppa; self; end)
    return if eigenclass.included_modules.include?(VerifablePPA)
    class << @ppa
      include VerifablePPA
    end
  end

  def copy_internal(packages, from_ppa)
    source_queue = Queue.new(packages.to_a)
    BlockingThreadPool.run(THREAD_COUNT) do
      until source_queue.empty?
        entry = source_queue.pop(true)
        source = entry[0]
        version = entry[1]
        Retry.retry_it do
          LOG.info "Copying source: #{source} (#{version});" \
                   " #{from_ppa.name} => #{@ppa.name}"
          @ppa.copyPackage!(from_archive: from_ppa.self_link,
                            source_name: source,
                            version: version,
                            to_pocket: 'Release',
                            include_binaries: true)
        end
      end
    end
  end
end

packages = JSON.parse(File.read('sources-list.json'))

Launchpad.authenticate

live = Archive.new(project.type, project.series)
snapshots = %w(daily)
snapshots << 'weekly' if DateTime.now.friday?
snapshots.each do |snapshot|
  LOG.info "Working on #{project.type}-#{snapshot}"
  ppa = Archive.new("#{project.type}-#{snapshot}", project.series)
  ppa.wipe
  ppa.copy(packages, live.ppa)
end

exit 0
