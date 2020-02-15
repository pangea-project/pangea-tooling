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

require_relative 'ci-tooling/lib/dci'
require_relative 'ci-tooling/lib/projects/factory'
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

  def initialize()
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
    DCI.series.each_key do |distribution|
      DCI.types.each do |type|
      file = "#{__dir__}/ci-tooling/data/projects/dci/#{distribution}/#{type}.yaml"
      next unless File.exist?(file)
      @arches = []
      if type == 'c1' || type == 'z1'
        @arches = ['armhf']
      elsif type == 'z2'
        @arches = ['arm64']
      else
        @arches = ['amd64']
      end
      projects = ProjectsFactory.from_file(file, branch: "master")
      all_builds = projects.collect do |project|
          DCIBuilderJobBuilder.job(
          project,
          distribution: distribution,
          type: type,
          architectures: @arches,
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
                                    distribution: distribution,
                                    downstream_jobs: all_builds)
      all_meta_builds << enqueue(meta_build)
      end
    end

    image_job_config =
      "#{File.expand_path(File.dirname(__FILE__))}/data/dci/dci.image.yaml"

    if File.exist? image_job_config
      image_jobs = YAML.load_stream(File.read(image_job_config))

      image_jobs.each do |image_job|
        image_job.each do |flavor, v|
          puts flavor
          v[:architectures].each do |arch|
            puts arch
            v[:types].each do |type|
              puts type
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
            end
          end
        end
      end
    end
    if File.exist? image_job_config
      snapshot_jobs = YAML.load_stream(File.read(image_job_config))
      snapshot_jobs.each do |snapshot_job|
        snapshot_job.each do |flavor, v|
          v[:architectures] ||= DCI.architectures
          v[:architectures].each do |arch|
            v[:types].each do |type|
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
    end


    # MGMT Jobs follow
    docker = enqueue(MGMTDockerJob.new(dependees: all_meta_builds))
    # enqueue(MGMTDockerCleanupJob.new(arch: 'armhf'))
    tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
    tooling_progenitor = enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_deploy]))
    tooling = enqueue(MGMTToolingJob.new(downstreams: [tooling_progenitor], dependees: []))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
    enqueue(MGMTRepoCleanupJob.new)
    enqueue(MGMTCreateDockerhubImagesJob.new)
    enqueue(MGMTCreateReposJob.new)
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new()
  updater.update
  updater.install_plugins
end
