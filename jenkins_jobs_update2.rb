#!/usr/bin/env ruby

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/thread_pool'
require_relative 'lib/jenkins/project_updater'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/nci/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @job_queue = Queue.new
    @flavor = 'nci'
    JenkinsJob.flavor_dir =
      "#{File.expand_path(File.dirname(__FILE__))}/jenkins-jobs/#{@flavor}"
  end

  def all_template_files
    files = super
    files + Dir.glob("#{JenkinsJob.flavor_dir}/templates/**.xml.erb")
  end

  private

  def populate_queue
    NCI.series.each_key do |distribution|
      NCI.types.each do |type|
        require_relative 'ci-tooling/lib/projects/factory'
        projects = ProjectsFactory.from_file("#{__dir__}/ci-tooling/data/projects/nci.yaml", branch: "Neon/#{type}")
        projects << Project.new('pkg-kde-tools', '', branch: 'kubuntu_xenial_archive')
        projects.sort_by!(&:name)
        projects.each do |project|
          jobs = ProjectJob.job(project, distribution: distribution, type: type, architectures: NCI.architectures)
          jobs.each { |j| enqueue(j) }
        end
        NCI.architectures.each do |architecture|
          isoargs = { type: type,
                      distribution: distribution,
                      architecture: architecture,
                      metapackage: 'neon-desktop',
                      imagename: 'neon' }
          enqueue(NeonIsoJob.new(isoargs))
          wayland_isoargs = { type: type,
                              distribution: distribution,
                              architecture: architecture,
                              metapackage: 'plasma-wayland-ci-live',
                              imagename: 'plasma-wayland' }
          enqueue(NeonIsoJob.new(wayland_isoargs))
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
