#!/usr/bin/env ruby

require_relative 'ci-tooling/lib/mobilekci'
require_relative 'ci-tooling/lib/dci'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'lib/jenkins/project_updater'

require 'optparse'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  MODULE_MAP = {
    dci: DCI,
    mci: MCI
  }.freeze

  def initialize(flavor:)
    super()
    @flavor = flavor
    @ci_module = MODULE_MAP[@flavor]

    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"

    upload_map = "#{__dir__}/data/#{@flavor}.upload.yaml"
    @upload_map = nil
    return unless File.exist?(upload_map)
    @upload_map = YAML.load_file(upload_map)
  end

  private

  def populate_queue
    # FIXME: maybe for meta lists we can use the return arrays via collect?
    all_meta_builds = []
    @ci_module.series.each_key do |distribution|
      @ci_module.types.each do |type|
        if ENV.key?('PANGEA_NEW_FACTORY')
          require_relative 'ci-tooling/lib/projects/factory'
          file = "#{__dir__}/ci-tooling/data/projects/#{@flavor}.yaml"
          projects = ProjectsFactory.from_file(file, branch: "kubuntu_#{type}")
        else
          projects = Projects.new(type: type, allow_custom_ci: true, projects_file: "ci-tooling/data/#{@flavor}.json")
        end
        all_builds = projects.collect do |project|
          Builder.job(project, distribution: distribution, type: type,
                               architectures: @ci_module.architectures,
                               upload_map: @upload_map)
        end
        all_builds.flatten!
        all_builds.each { |job| enqueue(job) }
        # Remove everything but source as they are the anchor points for
        # other jobs that might want to reference them.
        puts all_builds
        all_builds.reject! { |project| !project.job_name.end_with?('_src') }

        # This could actually returned into a collect if placed below
        all_meta_builds << enqueue(MetaBuildJob.new(type: type,
                                                    distribution: distribution,
                                                    downstream_jobs: all_builds))
      end

      image_job_config =
        "#{File.expand_path(File.dirname(__FILE__))}/data/#{@flavor}.image.yaml"

      if File.exist? image_job_config
        image_jobs = YAML.load_file(image_job_config)

        image_jobs.each do |_, v|
          enqueue(DCIImageJob.new(distribution: distribution,
                                  architecture: v[:architecture],
                                  repo: v[:repo],
                                  component: v[:component]))
        end
      end
    end

    # MGMT Jobs follow
    docker = enqueue(MGMTDockerJob.new(dependees: all_meta_builds))
    # enqueue(MGMTDockerCleanupJob.new(arch: 'armhf'))
    tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
    tooling_test = enqueue(MGMTToolingTestJob.new(downstreams: [tooling_deploy]))
    enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_test]))
    enqueue(MgmtProgenitorJob.new(downstream_jobs: all_meta_builds))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
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
