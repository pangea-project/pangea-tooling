#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require_relative 'ci-tooling/lib/kci'
require_relative 'ci-tooling/lib/projects/factory'
require_relative 'lib/jenkins/project_updater'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    super
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/"
  end

  private

  def populate_queue
    # FIXME: maybe for meta lists we can use the return arrays via collect?
    all_metas = []
    all_promoters = []
    all_mergers = []
    KCI.series.each_key do |distribution|
      KCI.types.each do |type|
        ProjectsFactory::Debian.instance_variable_set(:@url_base,
                                                      'git.debian.org:/git')
        file = "#{__dir__}/ci-tooling/data/projects/kci.yaml"
        projects = ProjectsFactory.from_file(file, branch: "kubuntu_#{type}")
        all_builds = projects.collect do |project|
          # FIXME: super fucked up dupe prevention
          if type == 'unstable' && distribution == KCI.series.keys[0]
            dependees = []
            # FIXME: I hate my life.
            # Mergers need to be upstreams to the build jobs otherwise the
            # build jobs can trigger before the merge is done (e.g. when)
            # there was an upstream change resulting in pointless build
            # cycles.
            KCI.series.each_key do |d|
              KCI.types.each do |t|
                dependees << BuildJob.build_name(d, t, project.name)
              end
            end
            all_mergers << enqueue(MergeJob.new(project, dependees: dependees))
          end

          enqueue(BuildJob.new(project, type: type, distribution: distribution))
        end
        all_promoters << enqueue(DailyPromoteJob.new(type: type,
                                                     distribution: distribution,
                                                     dependees: all_builds))

        # This could actually returned into a collect if placed below
        all_metas << enqueue(MetaBuildJob.new(type: type,
                                              distribution: distribution,
                                              downstream_jobs: all_builds))

        # FIXME: this maybe should be moved into MetaIsoJob or something
        # all_isos is actually unused
        KCI.architectures.each do |architecture|
          isoargs = { type: type,
                      distribution: distribution,
                      architecture: architecture }
          enqueue(IsoJob.new(isoargs))
        end
        # FIXME: doesn't automatically add new ISOs ...
        enqueue(MetaIsoJob.new(type: type, distribution: distribution))
      end
    end
    enqueue(MGMTDockerCleanupJob.new(arch: 'amd64'))
    merger = enqueue(MetaMergeJob.new(downstream_jobs: all_mergers))
    enqueue(MgmtProgenitorJob.new(downstream_jobs: all_metas,
                                  blockables: [merger]))
    enqueue(MGMTPauseIntegrationJob.new(downstreams: all_metas))
    docker = enqueue(MGMTDockerJob.new(dependees: all_metas + all_promoters))
    enqueue(MGMTToolingJob.new(downstreams: [docker]))
  end
end

if __FILE__ == $PROGRAM_NAME
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
