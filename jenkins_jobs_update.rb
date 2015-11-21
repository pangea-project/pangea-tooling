#!/usr/bin/env ruby

require_relative 'ci-tooling/lib/mobilekci'
require_relative 'ci-tooling/lib/dci'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/thread_pool'

require 'optparse'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', File.dirname(__FILE__))).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater

  MODULE_MAP = {
    dci: DCI,
    mci: MobileKCI
  }

  def initialize(flavor:)
    @job_queue = Queue.new
    @flavor = flavor
    @CI_MODULE = MODULE_MAP[@flavor]

    JenkinsJob.flavor_dir =
      "#{File.expand_path(File.dirname(__FILE__))}/jenkins-jobs/#{@flavor}"

    upload_map = "#{File.expand_path(File.dirname(__FILE__))}/data/#{@flavor}.upload.yaml"
    if File.exist? upload_map
      PublisherJob.upload_target_map = YAML.load_file(upload_map)
    end
  end

  def update
    populate_queue
    run_queue
  end

  def install_plugins
    # Autoinstall all possibly used plugins.
    installed_plugins = Jenkins.plugin_manager.list_installed.keys
    Dir.glob("#{JenkinsJob.flavor_dir}/**/**.xml.erb").each do |path|
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
    @CI_MODULE.series.each_key do |distribution|
      @CI_MODULE.types.each do |type|
        projects = Projects.new(type: type, allow_custom_ci: true, projects_file: "ci-tooling/data/#{@flavor}.json")
        all_builds = projects.collect do |project|
          Builder.job(project, distribution: distribution, type: type)
        end
        all_builds.flatten!
        all_builds.each { |job| enqueue(job) }
        # Remove everything but source as they are the anchor points for
        # other jobs that might want to reference them.
        all_builds.reject! { |project| !project.job_name.end_with?('_src') }

        # This could actually returned into a collect if placed below
        all_meta_builds << enqueue(MetaBuildJob.new(type: type, distribution: distribution, downstream_jobs: all_builds))
      end

      image_job_config =
        "#{File.expand_path(File.dirname(__FILE__))}/data/#{@flavor}.image.yaml"

      if File.exist? image_job_config
        image_jobs =
        YAML.load_file(image_job_config)

        image_jobs.each do |k, v|
          enqueue(DCIImageJob.new(distribution: distribution,
                                        architecture: v[:architecture],
                                        repo: v[:repo],
                                        component: v[:component]))
        end
      end
    end
    return unless @flavor == :mci

    # MGMT Jobs follow
    enqueue(MGMTDockerJob.new(dependees: all_meta_builds))
    # enqueue(MGMTDockerCleanupJob.new(arch: 'armhf'))
    enqueue(MgmtProgenitorJob.new(downstream_jobs: all_meta_builds))
  end
end

options = {}
options[:flavor] = :mci
OptionParser.new do |opts|
  opts.on('--ci [flavor]', [:dci, :mci], 'Run for CI flavor (dci, mci)') do |f|
    options[:flavor] = f
  end
end.parse!

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new(flavor: options[:flavor])
  updater.update
  updater.install_plugins
end
