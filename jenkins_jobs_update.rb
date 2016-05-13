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

require_relative 'ci-tooling/lib/mobilekci'
require_relative 'ci-tooling/lib/dci'
require_relative 'ci-tooling/lib/projects/factory'
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
        file = "#{__dir__}/ci-tooling/data/projects/#{@flavor}.yaml"
        projects = ProjectsFactory.from_file(file, branch: "kubuntu_#{type}")
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
        meta_build = MetaBuildJob.new(type: type,
                                      distribution: distribution,
                                      downstream_jobs: all_builds)
        all_meta_builds << enqueue(meta_build)
      end
    end

    image_job_config =
      "#{File.expand_path(File.dirname(__FILE__))}/data/#{@flavor}.image.yaml"

    if File.exist? image_job_config
      image_jobs = YAML.load_file(image_job_config)

      image_jobs.each do |flavor, v|
        @ci_module.architectures.each do |arch|
          v[:releases].each do |release, branch|
            enqueue(ImageJob.new(flavor: flavor,
                                    release: release,
                                    architecture: arch,
                                    repo: v[:repo],
                                    branch: branch))
          end
        end
      end
    end

    # MGMT Jobs follow
    docker = enqueue(MGMTDockerJob.new(dependees: all_meta_builds))
    # enqueue(MGMTDockerCleanupJob.new(arch: 'armhf'))
    tooling_deploy = enqueue(MGMTToolingDeployJob.new(downstreams: [docker]))
    tooling_test =
      enqueue(MGMTToolingTestJob.new(downstreams: [tooling_deploy]))
    enqueue(MGMTToolingProgenitorJob.new(downstreams: [tooling_test]))
    enqueue(MgmtProgenitorJob.new(downstream_jobs: all_meta_builds))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_meta_builds))
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {}
  options[:flavor] = :mci
  OptionParser.new do |opts|
    opts.on('--ci [flavor]', [:dci, :mci],
            'Run for CI flavor (dci, mci)') do |f|
      options[:flavor] = f
    end
  end.parse!

  updater = ProjectUpdater.new(flavor: options[:flavor])
  updater.update
  updater.install_plugins
end
