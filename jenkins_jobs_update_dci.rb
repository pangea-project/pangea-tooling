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
require_relative 'lib/kdeproject_component'

require 'sigdump/setup'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/dci/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @flavor = 'dci'
    @blacklisted_plugins = [
      'ircbot', # spammy drain on performance
      'instant-messaging' # dep of ircbot and otherwise useless
    ]
    @projects_dir = "#{__dir__}/data/projects"
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"
    upload_map = "#{__dir__}/data/dci.upload.yaml"
    @upload_map = nil
    return unless File.exist?(upload_map)

    @upload_map = YAML.load_file(upload_map)
    super
  end

  private

  def populate_queue
    CI::Overrides.default_files
    all_meta_builds = []
    DCI.series.each_key do |series|
      DCI.types.each do |release_type|
        DCI.architectures.each do |arch|
          data_dir = "#{@projects_dir}/#{@flavor}/#{series}/"
          data_file_name = "#{release_type}-#{arch}.yaml"
          projects_file = data_dir + data_file_name
          next unless File.exist?(projects_file)

          puts "Working on #{series}- #{release_type} - #{arch}"
          projects = ProjectsFactory.from_file(projects_file, branch: "Netrunnner/#{series}")
          all_builds = projects.collect do |project|
            DCIBuilderJobBuilder.job(
              project,
              release_type: release_type,
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
          all_builds.select! { |j| j.job_name.end_with?('_src') }
          # This could actually returned into a collect if placed below
          meta_build = MetaBuildJob.new(
            type: release_type,
            distribution: series,
            downstream_jobs: all_builds)
          all_meta_builds << enqueue(meta_build)
          image_job_config = "#{__dir__}/data/dci/dci.image.yaml"
          load_config = YAML.load_stream(File.read(image_job_config))
          next unless image_job_config

          image_jobs = load_config
          image_jobs.each do |r|
            r.each do |_type, v|
              arch = v['architecture']
              v[:releases].each do |release, branch|
                enqueue(
                  DCIImageJob.new(
                    release_type: release_type,
                    release: release,
                    architecture: arch,
                    repo: v[:repo],
                    branch: branch
                  )
                )
                v[:snapshots].each do |snapshot|
                next unless snapshot == release

                enqueue(
                  DCISnapShotJob.new(
                    snapshot: snapshot,
                    series: series,
                    release_type: release_type,
                    architecture: arch
                  )
                )
                end
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
    enqueue(MGMTToolingJob.new(downstreams: [tooling_progenitor], dependees: []))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
    enqueue(MGMTRepoCleanupJob.new)
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
