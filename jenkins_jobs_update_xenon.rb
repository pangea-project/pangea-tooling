#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2018 Harald Sitter <sitter@kde.org>
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

ENV['JENKINS_CONFIG'] = File.join(Dir.home, '.config/pangea-jenkins.json.xenon')

require_relative 'ci-tooling/lib/xenonci'
require_relative 'ci-tooling/lib/ci/overrides'
require_relative 'ci-tooling/lib/projects/factory'
require_relative 'lib/jenkins/project_updater'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/xenon/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @job_queue = Queue.new
    @flavor = 'xenon'
    @projects_dir = "#{__dir__}/ci-tooling/data/projects"
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"
    super
  end

  private

  def all_template_files
    files = super
    files + Dir.glob("#{JenkinsJob.flavor_dir}/templates/**.xml.erb")
  end

  def load_overrides!
    # TODO: there probably should be a conflict check so they don't override
    # the same thing.
    files = Dir.glob("#{__dir__}/ci-tooling/data/projects/overrides/xenon-*.yaml")
    # raise 'No overrides found?' if files.empty?
    CI::Overrides.default_files += files
  end

  def populate_queue
    load_overrides!

    all_builds = []

    XenonCI.series.each_key do |distribution|
      XenonCI.types.each do |type|
        projects_file = "#{@projects_dir}/xenon/#{distribution}/#{type}.yaml"
        projects = ProjectsFactory.from_file(projects_file,
                                             branch: "Neon/#{type}")
        projects.each do |project|
          j = XenonProjectJob.new(project,
                                  distribution: distribution,
                                  type: type,
                                  architectures: XenonCI.architectures)
          all_builds << enqueue(j)
        end
      end
    end

    # progenitor = enqueue(
    #   MgmtProgenitorJob.new(downstream_jobs: all_meta_builds,
    #                         blockables: [merger])
    # )

    # enqueue(MGMTWorkspaceCleanerJob.new(dist: NCI.current_series))
    # enqueue(MGMTJenkinsPruneParameterListJob.new)
    # enqueue(MGMTJenkinsArchive.new)

    # enqueue(MGMTRepoCleanupJob.new)

    docker = enqueue(MGMTDockerJob.new(dependees: []))
    # enqueue(MGMTGitSemaphoreJob.new)
    # enqueue(MGMTJobUpdater.new)
    # enqueue(MGMTDigitalOcean.new)
    # enqueue(MGMTDigitalOceanDangler.new)

    tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
    tooling_test =
      enqueue(MGMTToolingTestJob.new(downstreams: [tooling_deploy]))
    enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_test]))
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
