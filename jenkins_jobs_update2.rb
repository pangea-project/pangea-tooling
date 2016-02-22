#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects'
require_relative 'ci-tooling/lib/projects/factory'
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
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"
  end

  private

  # Append nci templates to list.
  def all_template_files
    files = super
    files + Dir.glob("#{JenkinsJob.flavor_dir}/templates/**.xml.erb")
  end

  def populate_queue
    all_builds = []
    all_meta_builds = []
    NCI.series.each_key do |distribution|
      NCI.types.each do |type|
        projects = ProjectsFactory.from_file("#{__dir__}/ci-tooling/data/projects/nci.yaml", branch: "Neon/#{type}")
        projects << Project.new('pkg-kde-tools', '', branch: 'kubuntu_xenial_archive')
        projects.sort_by!(&:name)
        projects.each do |project|
          jobs = ProjectJob.job(project,
                                distribution: distribution,
                                type: type,
                                architectures: NCI.architectures)
          jobs.each { |j| enqueue(j) }
          all_builds += jobs
        end

        # Meta builders.
        all_builds.reject! { |j| j.is_a?(ProjectJob) }
        meta_args = {
          type: type,
          distribution: distribution,
          downstream_jobs: all_builds
        }
        all_meta_builds << enqueue(MetaBuildJob.new(meta_args))

        # ISOs
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
    tooling = enqueue(MGMTToolingJob.new(downstreams: [docker]))
    progenitor = enqueue(MgmtProgenitorJob.new(downstream_jobs:
      all_meta_builds + tooling + docker))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: progenitor))
  end
end

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
