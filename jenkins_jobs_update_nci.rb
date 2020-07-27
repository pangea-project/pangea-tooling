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

# To only update some jobs run locally with e.g.
# PANGEA_FACTORIZE_ONLY='keurocalc' NO_UPDATE=1 UPDATE_INCLUDE='_keurocalc' ./jenkins_jobs_update_nci.rb

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

release_service_jobs = KDEProjectsComponent.release_service_jobs.collect do |app|
  "_kde_#{app}"
end

# Updates Jenkins Projects
class ProjectUpdater < Jenkins::ProjectUpdater
  def initialize
    @job_queue = Queue.new
    @flavor = 'nci'
    @blacklisted_plugins = [
      'ircbot', # spammy drain on performance
      'instant-messaging' # dep of ircbot and otherwise useless
    ]
    @projects_dir = "#{__dir__}/ci-tooling/data/projects"
    JenkinsJob.flavor_dir = "#{__dir__}/jenkins-jobs/#{@flavor}"
    super
  end

  private

  def jobs_without_template
    # FIXME: openqa is temporary while this is still being set up.
    JenkinsApi::Client.new.view.list_jobs('testy') +
      JenkinsApi::Client.new.job.list('^test_.*') +
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
          # Fairly akward special casing because snapcrafting is a bit
          # special-interest.
          # Also forced onto bionic, snapcraft porting requires special care
          # and is detatched from deb-tech more or less.
          if %w[unstable release].include?(type) && project.snapcraft &&
             !EXCLUDE_SNAPS.include?(project.name) && distribution == 'bionic'
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
                      %w[release_service frameworks plasma].include?(project.kdecomponent)
          watcher = WatcherJob.new(project)
          next if watchers.key?(watcher.job_name) # Already have one.
          watchers[watcher.job_name] = watcher
        end

        next if type == NCI.qt_stage_type

        # Meta builders.
        all_builds.select! { |j| j.is_a?(ProjectJob) }
        meta_builder = MetaBuildJob.new(type: type,
                                        distribution: distribution,
                                        downstream_jobs: all_builds)

        # Legacy distros deserve no daily builds. Only manual ones. So, do
        # not put them in the regular meta list and thus prevent progenitor from
        # even knowing about them.
        if distribution != NCI.old_series
          all_meta_builds << enqueue(meta_builder)
        end

        enqueue(DailyPromoteJob.new(type: type,
                                    distribution: distribution,
                                    dependees: [meta_builder]))

        enqueue(MGMTRepoTestVersionsJob.new(type: type,
                                            distribution: distribution))

        if (NCI.future_series && NCI.future_series == distribution) ||
           (NCI.old_series && NCI.current_series == distribution)
          enqueue(MGMTRepoTestVersionsUpgradeJob.new(type: type,
                                                     distribution: distribution))
        end
      end
      # end of type

      # ISOs
      NCI.architectures.each do |architecture|
        standard_args = {
          imagename: 'neon',
          distribution: distribution,
          architecture: architecture,
          metapackage: 'neon-desktop'
        }.freeze
        is_future = distribution == NCI.future_series

        dev_unstable_isoargs = standard_args.merge(
          type: 'unstable',
          neonarchive: 'unstable',
          cronjob: 'H H * * 0'
        )
        enqueue(NeonIsoJob.new(dev_unstable_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'unstable')))

        # Only make unstable ISO for the next series while in early mode.
        next if distribution == NCI.future_series && NCI.future_is_early

        dev_unstable_dev_isoargs = standard_args.merge(
          type: 'developer',
          neonarchive: 'unstable',
          cronjob: 'H H * * 1'
        )
        enqueue(NeonIsoJob.new(dev_unstable_dev_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'developer')))

        dev_stable_isoargs = standard_args.merge(
          type: 'testing',
          neonarchive: 'testing',
          cronjob: 'H H * * 2'
        )
        enqueue(NeonIsoJob.new(dev_stable_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'testing')))

        user_releaselts_isoargs = standard_args.merge(
          type: 'plasma_lts',
          neonarchive: is_future ? 'release/lts' : 'user/lts',
          cronjob: 'H H * * 3'
        )
        enqueue(NeonIsoJob.new(user_releaselts_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'plasma_lts')))

        user_release_isoargs = standard_args.merge(
          type: 'user',
          neonarchive: is_future ? 'release' : 'user',
          cronjob: 'H H * * 4'
        )
        enqueue(NeonIsoJob.new(user_release_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'user')))

        ko_user_release_isoargs = standard_args.merge(
          type: 'ko',
          neonarchive: 'testing',
          cronjob: 'H H * * 5',
          metapackage: 'neon-desktop-ko'
        )
        enqueue(NeonIsoJob.new(ko_user_release_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'ko')))

        mobile_isoargs = standard_args.merge(
          type: 'mobile',
          neonarchive: 'unstable',
          cronjob: 'H H * * 0',
          metapackage: 'plasma-phone'
        )
        enqueue(NeonIsoJob.new(mobile_isoargs))
        enqueue(MGMTTorrentISOJob.new(standard_args.merge(type: 'mobile')))
      end

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

      enqueue(MGMTRepoDivert.new(target: "unstable_#{distribution}"))
      enqueue(MGMTRepoDivert.new(target: "stable_#{distribution}"))

      enqueue(MGMTRepoUndoDivert.new(target: "unstable_#{distribution}"))
      enqueue(MGMTRepoUndoDivert.new(target: "stable_#{distribution}"))
    end

    # Docker hub changed API and I can not work out a way to trigger a build now so now use empty-push.sh from invent:neon-docker run on embra
    #enqueue(MGMTDockerHubRebuild.new(dependees: []))
    # Docker hub broke API with reponse frozen in Feb 2019.  Maybe it just needs the account's builds set up again but that needs Ben to do
    # jriddell 2019-11
    # enqueue(MGMTDockerHubCheck.new(dependees: []))
    enqueue(MGMTRepoMetadataCheck.new(dependees: []))

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
    enqueue(MGMTMergerDebianFrameworks.new)
    enqueue(MGMTGerminateJob.new(dist: NCI.current_series))
    enqueue(MGMTAppstreamHealthJob.new(dist: NCI.current_series))
    if NCI.future_series
      # Add generator jobs as necessary here. Probably sound to start out
      # with unstable first though.
      enqueue(MGMTAppstreamHealthJob.new(dist: NCI.future_series))
      enqueue(MGMTAppstreamGenerator.new(repo: 'dev/unstable',
                                         type: 'unstable',
                                         dist: NCI.future_series))
    end
    enqueue(MGMTJenkinsPruneParameterListJob.new)
    enqueue(MGMTJenkinsPruneOld.new)
    enqueue(MGMTGitSemaphoreJob.new)
    enqueue(MGMTJobUpdater.new)
    enqueue(MGMTDigitalOcean.new)
    enqueue(MGMTDigitalOceanDangler.new)
    enqueue(MGMTSeedDeploy.new)

    # This QA is only run for user edition, otherwise we'd end up in a nightmare
    # of which component is available in which edition but not the other.
    enqueue(MGMTAppstreamComponentsDuplicatesJob.new(type: 'user',
                                                     dist: NCI.current_series))

    # FIXME: this is hardcoded because we don't have a central map between
    #   'type' and repo path, additionally doing this programatically would
    #   require querying the aptly api. it's unclear if this is worthwhile.
    enqueue(MGMTAppstreamGenerator.new(repo: 'dev/unstable',
                                       type: 'unstable',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'dev/stable',
                                       type: 'stable',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'release',
                                       type: 'release',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'release/lts',
                                       type: 'release-lts',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'user',
                                       type: 'user',
                                       dist: NCI.current_series))
    enqueue(MGMTAppstreamGenerator.new(repo: 'user/lts',
                                       type: 'user-lts',
                                       dist: NCI.current_series))
    # Note for the future: when introducing a future_series it's probably wise
    # to split the job and asgen.rb for the new series. That way its easy to
    # drop legacy support when the time comes. At the time of writing both
    # things are highly coupled to their series, so treating them as something
    # generic is folly.

    enqueue(MGMTSnapshotUser.new(dist: NCI.current_series, origin: 'release', target: 'user'))
    enqueue(MGMTSnapshotUser.new(dist: NCI.current_series, origin: 'release-lts', target: 'user-lts'))
    if NCI.future_series
      enqueue(MGMTSnapshotUser.new(dist: NCI.future_series, origin: 'release', target: 'user'))
      enqueue(MGMTSnapshotUser.new(dist: NCI.future_series, origin: 'release-lts', target: 'user-lts'))
    end

    enqueue(MGMTVersionListJob.new(dist: NCI.current_series, type: 'user'))
    enqueue(MGMTToolingJob.new(downstreams: [],
                               dependees: []))
    enqueue(MGMTRepoCleanupJob.new)
  end
end

if $PROGRAM_NAME == __FILE__
  updater = ProjectUpdater.new
  updater.update
  updater.install_plugins
end
