#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) version 3, or any
# later version accepted by the membership of KDE e.V. (or its
# successor approved by the membership of KDE e.V.), which shall
# act as a proxy defined in Section 6 of version 3 of the license.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library.  If not, see <http://www.gnu.org/licenses/>.

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects/factory'
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
    @projects_dir = "#{__dir__}/ci-tooling/data/projects"
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
    all_mergers = []

    type_projects = {}
    NCI.types.each do |type|
      projects_file = "#{@projects_dir}/nci.yaml"
      projects_file = "#{@projects_dir}/nci_stable.yaml" if type == 'stable'
      projects = ProjectsFactory.from_file(projects_file,
                                           branch: "Neon/#{type}")
      type_projects[type] = projects

      next unless type == 'unstable'
      projects.each do |project|
        branch = project.packaging_scm.branch
        next unless branch && branch.start_with?('Neon/unstable', 'Neon/stable')
        # FIXME: this is fairly hackish
        dependees = []
        # Mergers need to be upstreams to the build jobs otherwise the
        # build jobs can trigger before the merge is done (e.g. when)
        # there was an upstream change resulting in pointless build
        # cycles.
        branches = NCI.types.collect { |x| "Neon/#{x}" }
        NCI.series.each_key do |d|
          NCI.types.each do |t|
            dependees << Builder.basename(d, t, project.component, project.name)
          end
        end
        all_mergers << enqueue(NCIMergerJob.new(project,
                                                dependees: dependees,
                                                branches: branches))
      end
    end

    NCI.series.each_key do |distribution|
      NCI.types.each do |type|
        type_projects[type].each do |project|
          jobs = ProjectJob.job(project,
                                distribution: distribution,
                                type: type,
                                architectures: NCI.architectures)
          jobs.each { |j| enqueue(j) }
          all_builds += jobs
        end

        # Meta builders.
        all_builds.reject! { |j| !j.is_a?(ProjectJob) }
        meta_args = {
          type: type,
          distribution: distribution,
          downstream_jobs: all_builds
        }
        all_meta_builds << enqueue(MetaBuildJob.new(meta_args))

        # ISOs
        NCI.architectures.each do |architecture|
          isoargs = { type: 'dev-unstable',
                      distribution: distribution,
                      architecture: architecture,
                      metapackage: 'neon-desktop',
                      imagename: 'neon' }
          enqueue(NeonIsoJob.new(isoargs))
          wayland_isoargs = { type: type,
                              distribution: distribution,
                              architecture: architecture,
                              metapackage: 'plasma-wayland-desktop',
                              imagename: 'plasma-wayland' }
          enqueue(NeonIsoJob.new(wayland_isoargs))
        end
      end
    end

    merger = enqueue(MetaMergeJob.new(downstream_jobs: all_mergers))
    progenitor = enqueue(
      MgmtProgenitorJob.new(downstream_jobs: all_meta_builds,
                            blockables: [merger])
    )
    enqueue(MGMTPauseIntegrationJob.new(downstreams: [progenitor]))
    docker = enqueue(MGMTDockerJob.new(dependees: [progenitor]))
    enqueue(MGMTToolingJob.new(downstreams: [docker]))
  end
end

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
