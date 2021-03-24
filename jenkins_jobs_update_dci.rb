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

require_relative 'lib/dci'
require_relative 'lib/projects/factory'
require_relative 'lib/jenkins/project_updater'

require 'optparse'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/dci/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater

  def initialize
    super()
    @ci_flavor = 'dci'

    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/dci"

    upload_map = "#{__dir__}/data/dci.upload.yaml"
    @upload_map = nil
    return unless File.exist?(upload_map)

    @upload_map = YAML.load_file(upload_map)
  end

  private

  def populate_queue
    CI::Overrides.default_files
    # FIXME: maybe for meta lists we can use the return arrays via collect?
    all_meta_builds = []
    @project_file = ''
    DCI.series.each_key do |series|
      DCI.types.each do |type|
        DCI.architectures.each do |arch|
          if arch.include? '^arm'
            DCI.arm_boards.each do |armboard|
              @project_file = "data/projects/dci/#{series}/#{type}-#{armboard}.yaml"
            end
          else
            @project_file =  "data/projects/dci/#{series}/#{type}.yaml"
          end
          projects = ProjectsFactory.from_file(@project_file, branch: "master")
          all_builds = projects.collect do |project|
          DCIBuilderJobBuilder.job(
            project,
            type: type,
            series: series,
            architecture: arch,
            upload_map: @upload_map
        )
      end
      all_builds.flatten!
      all_builds.each { |job| enqueue(job) }
        # Remove everything but source as they are the anchor points for
        # other jobs that might want to reference them.
      puts all_builds
      all_builds.select! { |project| project.job_name.end_with?('_src') }

        # This could actually returned into a collect if placed below
      meta_build = MetaBuildJob.new(type: type,
                                    distribution: series,
                                    downstream_jobs: all_builds)
      all_meta_builds << enqueue(meta_build)
      end
    end

    image_job_config =
      "#{__dir__}/data/dci/dci.image.yaml"
    load_config = YAML.load_stream(File.read(image_job_config))

    if File.exist? image_job_config
      image_jobs = load_config

      image_jobs.each do |type|
        type.each do |flavor, v|
         arch = v['architecture']
         v[:releases].each do |release, branch|
            enqueue(
                DCIImageJob.new(
                  flavor: flavor,
                  release: release,
                  architecture: arch,
                  repo: v[:repo],
                  branch: branch
                  )
                )
         end
        v[:snapshots].each do |snapshot|
            enqueue(
              SnapShotJob.new(
                snapshot: snapshot,
                flavor: flavor,
                architecture: arch
                )
              )
           end
         end
      end
    end
  end
 # MGMT Jobs follow
 docker = enqueue(MGMTDockerJob.new(dependees: all_meta_builds))
  # enqueue(MGMTDockerCleanupJob.new(arch: 'armhf'))
 tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
 tooling_progenitor = enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_deploy]))
 enqueue(MGMTToolingJob.new(downstreams: [tooling_progenitor], dependees: []))
 enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
 enqueue(MGMTRepoCleanupJob.new)
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new()
  updater.update
  updater.install_plugins
end
