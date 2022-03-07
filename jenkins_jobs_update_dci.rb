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

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).sort.each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/dci/*.rb', __dir__)).sort.each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @blacklisted_plugins = [
      'ircbot', # spammy drain on performance
      'instant-messaging' # dep of ircbot and otherwise useless
    ]
    @data_dir = File.expand_path('data', __dir__)
    @projects_dir = File.expand_path('projects/dci', @data_dir)
    upload_map_file = File.expand_path('dci.upload.yaml', @data_dir)
    JenkinsJob.flavor_dir = File.expand_path('jenkins-jobs/dci', __dir__)
    return unless File.exist?(upload_map_file)

    @upload_map = true
    @stamp = DateTime.now.strftime('Y%m%d.%H%M')
    @dci_release = ''
    @release_arch = ''
    @release_type = ''
    @series = ''
    super
  end

  private

  def populate_queue
    all_builds = []
    jobs = []
    CI::Overrides.default_files
    DCI.series.each do |base_os_id, series_version|
      next unless base_os_id.starts_with?('netrunner')

      DCI.release_types.each do |release_type|
        DCI.releases_for_type(release_type).each do |dci_release|
          @type = @series == 'next' ? 'unstable' : 'stable'
          @series = DCI.series_version_codename(series_version)
          puts "Base OS: #{base_os_id} Varient: #{release_type} Series: #{@series}"
          @release_type = release_type
          @dci_release = dci_release
          puts "Release: #{@dci_release}"

          @release_data = DCI.get_release_data(@release_type, @dci_release)
          @arm = DCI.arm_board_by_release(@release_data)
          @release_arch = DCI.arch_by_release(@release_data)
          @release_distribution = DCI.release_distribution(@dci_release, @series)
          data_file_name = DCI.arm?(@dci_release) ? "#{@release_type}-#{@arm}.yaml" : "#{@release_type}.yaml"
          projects_data_dir = File.expand_path(@series, @projects_dir)
          puts "Working on Series: #{@series} Release: #{@dci_release} Architecture: #{@release_arch}"
          file = File.expand_path(data_file_name, projects_data_dir)
          raise "#{file} doesn't exist!" unless file

          @release_image_data = DCI.release_image_data(@release_type, @dci_release)
          image_repo = @release_image_data[:repo]
          branch = @release_image_data[:series_branches][@series]
          projects = ProjectsFactory.from_file(file, branch: branch)
          raise 'Pointless without projects, something went wrong' unless projects

          projects.each do |project|
            jobs = DCIProjectMultiJob.job(
              project,
              type: @type,
              release_type: @release_type,
              release: @dci_release,
              series: @series,
              distribution: @release_distribution,
              architecture: @release_arch,
              upload_map: @upload_map
            )
          end
          jobs.each { |j| enqueue(j) }
          all_builds += jobs

          enqueue(
            DCIImageJob.new(
              release: @dci_release,
              release_type: @release_type,
              series: @series,
              architecture: @release_arch,
              repo: image_repo,
              branch: branch
            )
          )
          enqueue(
            DCISnapShotJob.new(
              series: @series,
              release_type: @release_type,
              release: @dci_release,
              architecture: @release_arch,
              arm_board: @arm
            )
          )
        end
      end
    end

    docker = enqueue(MGMTDCIDockerJob.new(dependees: []))
    tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
    tooling_progenitor = enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_deploy]))
    enqueue(MGMTToolingJob.new(downstreams: [tooling_progenitor], dependees: []))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
    enqueue(MGMTRepoCleanupJob.new)
    enqueue(MGMTDCIReleaseBranchingJob.new)
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new
  updater.install_plugins
  updater.update
end
