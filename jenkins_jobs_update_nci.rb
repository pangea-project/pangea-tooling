#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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

# To only update some jobs run on drax with e.g.
# NO_UPDATE=1 UPDATE_INCLUDE='_calamares_' ./tooling/jenkins_jobs_update_nci.rb

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects/factory'
require_relative 'lib/jenkins/project_updater'
require_relative 'lib/kdeproject_component'

Dir.glob(File.expand_path('jenkins-jobs/*.rb', __dir__)).each do |file|
  require file
end

Dir.glob(File.expand_path('jenkins-jobs/nci/*.rb', __dir__)).each do |file|
  require file
end

# FIXME: this really shouldn't be in here. need some snap job builder or something
EXCLUDE_SNAPS = %w[
  eventviews gpgmepp grantleetheme incidenceeditor
  kaccounts-integration kcalcore kcalutils kcron kde-dev-scripts
  kdepim-addons kdepim-apps-libs kdgantt2 kholidays
  kidentitymanagement kimap kldap kmailtransport kmbox kmime
  kontactinterface kpimtextedit ktnef libgravatar libkdepim libkleo
  libkmahjongg libkomparediff2 libksieve mailcommon mailimporter
  messagelib pimcommon signon-kwallet-extension syndication akonadi
  akonadi-calendar akonadi-search calendarsupport kalarmcal kblog
  kcontacts kleopatra kdepim kdepim-runtime kdepimlibs baloo-widgets
  ffmpegthumbs dolphin-plugins akonadi-mime akonadi-notes analitza
  kamera kdeedu-data kdegraphics-thumbnailers kdenetwork-filesharing
  kdesdk-thumbnailers khelpcenter kio-extras kqtquickcharts kuser
  libkdcraw libkdegames libkeduvocdocument libkexiv2 libkface
  libkgeomap libkipi libksane poxml akonadi-contacts print-manager
  marble khangman kdevplatform sddm kdevelop-python kdevelop-php
  phonon-backend-vlc phonon-backend-gstreamer ktp-common-internals
  kaccounts-providers kdevelop-pg-qt kwalletmanager kdialog svgpart
  libkcddb libkcompactdisc mbox-importer akonadi-calendar-tools
  akonadi-import-wizard audiocd-kio grantlee-editor kdegraphics-mobipocket
  kmail-account-wizard konqueror libkcddb libkcompactdisc pim-data-exporter
  pim-sieve-editor pim-storage-service-manager kdegraphics-mobipocket
  akonadiconsole akregator kdav kmail knotes blogilo libkgapi kgpg
  kapptemplate kcachegrind kde-dev-utils kdesdk-kioslaves korganizer
  kfind kfloppy kaddressbook konsole krfb ksystemlog
].freeze

applications_jobs = KDEProjectsComponent.applications.collect do |app|
  "_kde_#{app}"
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @job_queue = Queue.new
    @flavor = 'nci'
    @projects_dir = "#{__dir__}/ci-tooling/data/projects"
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"
    super
  end

  private

  def jobs_without_template
    # FIXME: openqa is temporary while this is still being set up.
    JenkinsApi::Client.new.view.list_jobs('testy') +
      JenkinsApi::Client.new.job.list('^test_.*') +
      JenkinsApi::Client.new.job.list('^openqa.*') +
      %w[a_extra-cmake-modules] # This is a multibranch pipe, a view itself.
  end

  # Append nci templates to list.
  def all_template_files
    files = super
    files + Dir.glob("#{JenkinsJob.flavor_dir}/templates/**.xml.erb")
  end

  def load_overrides!
    # TODO: there probably should be a conflict check so they don't override
    # the same thing.
    files = Dir.glob("#{__dir__}/ci-tooling/data/projects/overrides/nci-*.yaml")
    raise 'No overrides found?' if files.empty?
    CI::Overrides.default_files += files
  end

  def populate_queue
    load_overrides!

    all_meta_builds = []
    all_mergers = []
    type_projects = {}

    NCI.types.each do |type|
      projects_file = "#{@projects_dir}/nci/#{type}.yaml"
      projects = ProjectsFactory.from_file(projects_file,
                                           branch: "Neon/#{type}")
      type_projects[type] = projects

      next unless type == 'unstable'
      projects.each do |project|
        branch = project.packaging_scm.branch
        branches = NCI.types.collect do |t|
          # We have Neon/type and Neon/type_series if a branch is only
          # applicable to a specific series.
          ["Neon/#{t}"] + NCI.series.collect { |s, _| "Neon/#{t}_#{s}" }
        end.flatten
        branches << 'master'
        next unless branch&.start_with?(*branches)

        # FIXME: this is fairly hackish
        dependees = []
        # Mergers need to be upstreams to the build jobs otherwise the
        # build jobs can trigger before the merge is done (e.g. when)
        # there was an upstream change resulting in pointless build
        # cycles.
        NCI.series.each_key do |series|
          NCI.types.each do |type_for_dependee|
            dependees << BuilderJobBuilder.basename(series,
                                                    type_for_dependee,
                                                    project.component,
                                                    project.name)
          end
        end
        all_mergers << enqueue(NCIMergerJob.new(project,
                                                dependees: dependees,
                                                branches: branches))
      end
    end

    watchers = {}
    NCI.series.each_key do |distribution|
      NCI.types.each do |type|
        all_builds = [] # Tracks all builds in this type.

        type_projects[type].each do |project|
          if !project.series_restrictions.empty? &&
             !project.series_restrictions.include?(distribution)
            warn "#{project.name} has been restricted to" \
                 " #{project.series_restrictions}." \
                 " We'll not create a job for #{distribution}."
            next
          end
          # Fairly akward special casing this. Snaps only build releases right
          # now.
          # FIXME: xenial hardcoded because moving to bionic requires some
          #   changes to how the framework snap is built and named and handled
          #   to avoid ABI issues.
          is_app = KDEProjectsComponent.applications.include?(project.name)
          if type == 'release' && (is_app || project.name == 'konversation') &&
             !EXCLUDE_SNAPS.include?(project.name) && distribution == 'xenial'
            enqueue(AppSnapJob.new(project.name))
          end
          if type == 'unstable' && project.snapcraft &&
             !EXCLUDE_SNAPS.include?(project.name) && distribution == 'xenial'
            enqueue(SnapcraftJob.new(project,
                                     distribution: distribution, type: type))
          end
          # enable ARM for xenial- & bionic-unstable and bionic-release
          project_architectures = if type == 'unstable' ||
                                     (type == 'release' && distribution != 'xenial')
                                    NCI.all_architectures
                                  else
                                    NCI.architectures
                                  end
          jobs = ProjectJob.job(project,
                                distribution: distribution,
                                type: type,
                                architectures: project_architectures)

          jobs.each { |j| enqueue(j) }
          all_builds += jobs

          # FIXME: presently not forcing release versions of things we have a
          #   stable for
          next unless type == 'release'
          next unless %w[neon-packaging extras kde].include?(project.component) ||
                      %w[applications frameworks plasma].include?(project.kdecomponent)
          watcher = WatcherJob.new(project)
          next if watchers.key?(watcher.job_name) # Already have one.
          watchers[watcher.job_name] = watcher
        end

        next if type.start_with?('testing')

        # Meta builders.
        all_builds.select! { |j| j.is_a?(ProjectJob) }
        meta_builder = MetaBuildJob.new(type: type,
                                        distribution: distribution,
                                        downstream_jobs: all_builds)
        all_meta_builds << enqueue(meta_builder)

        enqueue(DailyPromoteJob.new(type: type,
                                    distribution: distribution,
                                    dependees: [meta_builder]))

        enqueue(MGMTRepoTestVersionsJob.new(type: type,
                                            distribution: distribution))
      end
      # end of type

      next if distribution == 'xenial' # No more xenial ISOs

      # ISOs
      NCI.architectures.each do |architecture|
        dev_unstable_isoargs = { type: 'devedition-gitunstable',
                                 distribution: distribution,
                                 architecture: architecture,
                                 metapackage: 'neon-desktop',
                                 imagename: 'neon',
                                 neonarchive: 'dev/unstable',
                                 cronjob: 'H H * * 0' }
        enqueue(NeonIsoJob.new(dev_unstable_isoargs))
        dev_unstable_dev_name = 'devedition-gitunstable-development'
        dev_unstable_dev_isoargs = { type: dev_unstable_dev_name,
                                     distribution: distribution,
                                     architecture: architecture,
                                     metapackage: 'neon-desktop',
                                     imagename: 'neon-development',
                                     neonarchive: 'dev/unstable',
                                     cronjob: 'H H * * 1' }
        enqueue(NeonIsoJob.new(dev_unstable_dev_isoargs))
        dev_stable_isoargs = { type: 'devedition-gitstable',
                               distribution: distribution,
                               architecture: architecture,
                               metapackage: 'neon-desktop',
                               imagename: 'neon',
                               neonarchive: 'dev/stable',
                               cronjob: 'H H * * 2' }
        enqueue(NeonIsoJob.new(dev_stable_isoargs))
        user_releaselts_isoargs = { type: 'userltsedition',
                                    distribution: distribution,
                                    architecture: architecture,
                                    metapackage: 'neon-desktop',
                                    imagename: 'neon',
                                    neonarchive: 'user/lts',
                                    cronjob: 'H H * * 3' }
        enqueue(NeonIsoJob.new(user_releaselts_isoargs))
        user_release_isoargs = { type: 'useredition',
                                 distribution: distribution,
                                 architecture: architecture,
                                 metapackage: 'neon-desktop',
                                 imagename: 'neon',
                                 neonarchive: 'user',
                                 cronjob: 'H H * * 4' }
        enqueue(NeonIsoJob.new(user_release_isoargs))
        ko_user_release_isoargs = { type: 'devedition-gitstable',
                                    distribution: distribution,
                                    architecture: architecture,
                                    metapackage: 'neon-desktop-ko',
                                    imagename: 'neon-ko',
                                    neonarchive: 'dev/stable',
                                    cronjob: 'H H * * 5' }
        enqueue(NeonIsoJob.new(ko_user_release_isoargs))
      end

      # The following images are only pertaining to dists that aren't xenial.
      # This isn't necessarily restricted to bionic or anything.
      if distribution != 'xenial'
        dev_unstable_imgargs = { type: 'devedition-gitunstable',
                                 distribution: distribution,
                                 architecture: 'arm64',
                                 metapackage: 'neon-desktop',
                                 imagename: 'neon',
                                 neonarchive: 'dev/unstable',
                                 cronjob: 'H H * * 0' }
        enqueue(NeonImgJob.new(dev_unstable_imgargs))
        user_imgargs = { type: 'useredition',
                         distribution: distribution,
                         architecture: 'arm64',
                         metapackage: 'neon-desktop',
                         imagename: 'neon',
                         neonarchive: 'user',
                         cronjob: 'H H * * 0'}
        enqueue(NeonImgJob.new(user_imgargs))
      end
    end

    # Watchers is a hash, only grab the actual jobs and enqueue them.
    watchers.each_value { |w| enqueue(w) }

    merger = enqueue(MetaMergeJob.new(downstream_jobs: all_mergers))
    progenitor = enqueue(
      MgmtProgenitorJob.new(downstream_jobs: all_meta_builds,
                            blockables: [merger])
    )
    enqueue(MGMTPauseIntegrationJob.new(downstreams: [progenitor]))
    enqueue(MGMTAptlyJob.new(dependees: [progenitor]))
    enqueue(MGMTWorkspaceCleanerJob.new(dist: NCI.current_series))
    docker = enqueue(MGMTDockerJob.new(dependees: []))
    enqueue(MGMTMergerDebianFrameworks.new)
    enqueue(MGMTGerminateJob.new(dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'user',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new('-lts', repo: 'user/lts',
                                               dist: NCI.current_series))
    enqueue(MGMTAppstreamHealthJob.new(dist: NCI.current_series))
    if NCI.future_series
      enqueue(MGMTAppstreamHealthJob.new(dist: NCI.future_series))
    end
    enqueue(MGMTAppstreamGenerator.new(repo: 'user',
                                       dist: NCI.future_series))
    enqueue(MGMTAppstreamGenerator.new('-lts', repo: 'user/lts',
                                               dist: NCI.future_series))
    enqueue(MGMTJenkinsPruneParameterListJob.new)
    enqueue(MGMTJenkinsArchive.new)
    enqueue(MGMTGitSemaphoreJob.new)
    enqueue(MGMTJobUpdater.new)
    enqueue(MGMTDigitalOcean.new)
    enqueue(MGMTDigitalOceanDangler.new)

    enqueue(MGMTSnapshotUser.new(dist: NCI.current_series))
    enqueue(MGMTSnapshotUserLTS.new(dist: NCI.current_series))
    enqueue(MGMTSnapshotUser.new(dist: NCI.future_series))
    enqueue(MGMTSnapshotUserLTS.new(dist: NCI.future_series))

    enqueue(MGMTRepoDivert.new(target: 'unstable_bionic'))
    enqueue(MGMTRepoDivert.new(target: 'unstable_xenial'))
    enqueue(MGMTRepoDivert.new(target: 'stable_bionic'))
    enqueue(MGMTRepoDivert.new(target: 'stable_xenial'))

    enqueue(MGMTRepoUndoDivert.new(target: 'unstable_bionic'))
    enqueue(MGMTRepoUndoDivert.new(target: 'unstable_xenial'))
    enqueue(MGMTRepoUndoDivert.new(target: 'stable_bionic'))
    enqueue(MGMTRepoUndoDivert.new(target: 'stable_xenial'))

    enqueue(MGMTToolingJob.new(downstreams: [docker],
                               dependees: []))
    enqueue(MGMTRepoCleanupJob.new)
    enqueue(MGMTDockerHubRebuild.new(dependees: []))
    enqueue(MGMTDockerHubCheck.new(dependees: []))
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
