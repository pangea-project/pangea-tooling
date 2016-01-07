#!/usr/bin/env ruby

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/thread_pool'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater
  def initialize
    @job_queue = Queue.new
    JenkinsJob.flavor_dir =
      "#{File.expand_path(File.dirname(__FILE__))}/jenkins-jobs/#{@flavor}"
  end

  def update
    populate_queue
    run_queue
  end

  def plugins_to_install
    plugins = []
    installed_plugins = Jenkins.plugin_manager.list_installed.keys
    Dir.glob('jenkins-jobs/templates/**/**.xml.erb').each do |path|
      next if path.include?('/dci/') || path.include?('/mci/')
      File.readlines(path).each do |line|
        match = line.match(/.*plugin="(.+)".*/)
        next unless match && match.size == 2
        plugin = match[1].split('@').first
        next if installed_plugins.include?(plugin)
        plugins << plugin
      end
    end
    plugins.uniq.compact
  end

  def install_plugins
    # Autoinstall all possibly used plugins.
    installed_plugins = Jenkins.plugin_manager.list_installed.keys
    plugins_to_install.each do |plugin|
      next if installed_plugins.include?(plugin)
      puts "--- Installing #{plugin} ---"
      Jenkins.plugin_manager.install(plugin)
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
        job.update
      end
    end
  end

  def populate_queue
    all_meta_builds = []
    NCI.series.each_key do |distribution|
      NCI.types.each do |type|
        projects = Projects.new(type: type,
                                projects_file: 'ci-tooling/data/projects_nci.json')
        projects << Project.new('pkg-kde-tools', '', branch: 'kubuntu_xenial_archive')
        projects.each do |project|
          builder = Builder2.job(project, distribution: distribution, type: type, architectures: NCI.architectures)
          builder.each { |b| enqueue(b) }
        end
      end
    end
    docker = enqueue(MGMTDockerJob.new(dependees: []))
    enqueue(MGMTToolingJob.new(downstreams: [docker]))
  end
end

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
