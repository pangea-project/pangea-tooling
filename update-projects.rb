#!/usr/bin/env ruby

require 'thwait'

require_relative 'ci-tooling/lib/projects'

require_relative 'jenkins-jobs/build'
require_relative 'jenkins-jobs/daily-promote'
require_relative 'jenkins-jobs/iso'
require_relative 'jenkins-jobs/merge'
require_relative 'jenkins-jobs/meta-build'
require_relative 'jenkins-jobs/meta-iso'
require_relative 'jenkins-jobs/meta-merge'
require_relative 'jenkins-jobs/mgmt-lxc'
require_relative 'jenkins-jobs/progenitor'

# Simple thread pool implementation. Pass a block to run and it runs it in a
# pool.
# Note that the block code should be thread safe...
module BlockingThreadPool
  # Runs the passed block in a pool. This function blocks until all threads are
  # done.
  # @param count the thread count to use for the pool
  def self.run(count = 16, &block)
    threads = []
    count.times { threads << Thread.new(nil, &block) }
    ThreadsWait.all_waits(threads)
  end
end

# Updates Jenkins Projects
class ProjectUpdater
  ARCHITECTURES = %w(amd64 i386)
  DISTRIBUTIONS = %w(vivid utopic)
  TYPES = %w(unstable stable)

  def initialize
    @job_queue = Queue.new
  end

  def update
    populate_queue
    run_queue
  end

  def install_plugins
    # Autoinstall all possibly used plugins.
    installed_plugins = Jenkins.plugin_manager.list_installed.keys
    Dir.glob('jenkins-jobs/templates/**/**.xml.erb').each do |path|
      File.readlines(path).each do |line|
        match = line.match(/.*plugin="(.+)".*/)
        next unless match && match.size == 2
        plugin = match[1].split('@').first
        next if installed_plugins.include?(plugin)
        puts "--- Installing #{plugin} ---"
        Jenkins.plugin_manager.install(plugin)
      end
    end
  end

  private

  def enqueue(obj)
    @job_queue << obj
    obj
  end

  def run_queue
    BlockingThreadPool.run do
      until @job_queue.empty?
        job = @job_queue.pop(true)
        begin
          job.update
        rescue => e
          print "Error on job update :: #{e}\n"
        end
      end
    end
  end

  def populate_queue
    # FIXME: maybe for meta lists we can use the return arrays via collect?
    all_meta_builds = []
    all_mergers = []
    DISTRIBUTIONS.each do |distribution|
      TYPES.each do |type|
        enqueue(DailyPromoteJob.new(distribution: distribution, type: type))
        projects = Projects.new(type: type)
        all_builds = projects.collect do |project|
          # FIXME: super fucked up dupe prevention
          if type == 'unstable' && distribution == 'vivid'
            dependees = []
            # FIXME: I hate my life.
            # Mergers need to be upstreams to the build jobs otherwise the
            # build jobs can trigger before the merge is done (e.g. when)
            # there was an upstream change resulting in pointless build
            # cycles.
            DISTRIBUTIONS.each do |d|
              TYPES.each do |t|
                dependees << BuildJob.build_name(d, t, project.name)
              end
            end
            all_mergers << enqueue(MergeJob.new(project, dependees: dependees))
          end

          enqueue(BuildJob.new(project, type: type, distribution: distribution))
        end
        # This could actually returned into a collect if placed below
        all_meta_builds << enqueue(MetaBuildJob.new(type: type, distribution: distribution, downstream_jobs: all_builds))

        # FIXME: this maybe should be moved into MetaIsoJob or something
        # all_isos is actually unused
        ARCHITECTURES.each do |architecture|
          args = { type: type,
                   distribution: distribution,
                   architecture: architecture }
          enqueue(IsoJob.new(args))
          enqueue(MGMTLXCJob.new(args))
        end
        # FIXME: doesn't automatically add new ISOs ...
        enqueue(MetaIsoJob.new(type: type, distribution: distribution))
      end
    end
    enqueue(MetaMergeJob.new(downstream_jobs: all_mergers))
    enqueue(MgmtProgenitorJob.new(downstream_jobs: all_meta_builds))
  end
end

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
