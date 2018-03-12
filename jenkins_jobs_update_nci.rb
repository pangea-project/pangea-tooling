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

require_relative 'ci-tooling/lib/nci'
require_relative 'ci-tooling/lib/projects/factory'
require_relative 'lib/jenkins/project_updater'
require_relative 'lib/kdeproject_component'
require 'httparty'

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
  marble khangman bovo kdevplatform sddm kdevelop-python kdevelop-php
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

# Types to use for future series. Others get skipped.
FUTURE_TYPES = %w[unstable].freeze
# Skip certain job bits for future series.
# The bottom part of this list is temporary until qt is staged.
# _pkg-kde-tools_ is definitely lower version than what is in bionic, unclear
# if we still need it.

applications_jobs = KDEProjectsComponent.applications.collect { "_kde_#{app}" }

FUTURE_SKIP = applications_jobs + %w[
  _kde-extras_
  iso_neon_
  iso_neon-
  img_neon_
  mgmt_daily_promotion_bionic_

  _pkg-kde-tools_
  _backports-xenial_
  _forks_
  _neon-packaging_
  _launchpad_
  _unstable_neon_
].freeze

# Opposite of above, allows including part of the jobs within a skip rule
FUTURE_INCLUDE = %w[
  _kde-extras_kdevelop
  _kde-extras_phonon
  _kde-extras_sddm
  _kde_ark
  _kde_dolphin
  _kde_gwenview
  _kde_kdialog
  _kde_konsole
  _kde_kate
  _kde_print-manager
  _kde_okular
  _kde_spectacle
].freeze

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

  def enqueue(job)
    future = job.job_name.include?(NCI.future_series)
    whitelisted = FUTURE_INCLUDE.any? { |x| job.job_name.include?(x) }
    skip = FUTURE_SKIP.any? { |x| job.job_name.include?(x) }
    # if a job is not whitelisted and a future-skip we'll not enqueue it
    return if (!whitelisted && (future && skip))
    # else run
    super
  end

  def populate_queue
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
        # FIXME: this is fairly hackish
        dependees = []
        # Mergers need to be upstreams to the build jobs otherwise the
        # build jobs can trigger before the merge is done (e.g. when)
        # there was an upstream change resulting in pointless build
        # cycles.
        branches = NCI.types.collect { |x| "Neon/#{x}" } << 'master'
        next unless branch&.start_with?(*branches)
        NCI.series.each_key do |series|
          NCI.types.each do |type_for_dependee|
            # Skip if the type isn't enabled for future series.
            next if series == NCI.future_series &&
                    !FUTURE_TYPES.include?(type_for_dependee)
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
        # Skip if the type isn't enabled for future series.
        next if distribution == NCI.future_series &&
                !FUTURE_TYPES.include?(type)

        all_builds = [] # Tracks all builds in this type.

        type_projects[type].each do |project|
          # Fairly akward special casing this. Snaps only build releases right
          # now.
          if type == 'release' && KDEProjectsComponent.applications.include?(project.name) &&
             !EXCLUDE_SNAPS.include?(project.name)
            enqueue(AppSnapJob.new(project.name))
          end
          if type == 'unstable' && project.snapcraft &&
             !EXCLUDE_SNAPS.include?(project.name)
            enqueue(SnapcraftJob.new(project,
                                     distribution: distribution, type: type))
          end
          project_architectures = if type == 'unstable'
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
          next unless %w[neon-packaging kde-extras].include?(project.component) || 
            %w[applications frameworks plasma].include?(project.kdecomponent)
          watcher = WatcherJob.new(project)
          next if watchers.key?(watcher.job_name) # Already have one.
          watchers[watcher.job_name] = watcher
        end

        next if type.start_with?('testing')

        # Meta builders.
        all_builds.select! { |j| j.is_a?(ProjectJob) }
        meta_args = {
          type: type,
          distribution: distribution,
          downstream_jobs: all_builds
        }
        meta_builder = MetaBuildJob.new(meta_args)
        all_meta_builds << enqueue(meta_builder)

        enqueue(DailyPromoteJob.new(type: type,
                                    distribution: distribution,
                                    dependees: [meta_builder]))

        enqueue(MGMTRepoTestVersionsJob.new(type: type,
                                            distribution: distribution))
      end
      # end of type

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
      dev_unstable_imgargs = { type: 'devedition-gitunstable',
                               distribution: distribution,
                               architecture: 'arm64',
                               metapackage: 'neon-desktop',
                               imagename: 'neon',
                               neonarchive: 'dev/unstable',
                               cronjob: 'H H * * 0' }
      enqueue(NeonImgJob.new(dev_unstable_imgargs))
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
    enqueue(MGMTJenkinsPruneParameterListJob.new)
    enqueue(MGMTJenkinsArchive.new)
    enqueue(MGMTGitSemaphoreJob.new)
    enqueue(MGMTJobUpdater.new)
    enqueue(MGMTDigitalOcean.new)
    enqueue(MGMTDigitalOceanDangler.new)
    enqueue(MGMTSnapshot.new(dist: NCI.current_series, origin: 'release',
                             target: 'user', appstream: ''))
    enqueue(MGMTSnapshot.new(dist: NCI.current_series, origin: 'release-lts',
                             target: 'user-lts', appstream: '-lts'))
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
