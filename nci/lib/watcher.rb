# coding: utf-8
# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'pp'

require_relative '../../lib/debian/changelog'
require_relative '../../lib/debian/uscan'
require_relative '../../lib/debian/version'
require_relative '../../lib/nci'

require_relative '../../lib/kdeproject_component'
require_relative '../../lib/pangea/mail'

require 'shellwords'
require 'tty-command'

module NCI
  # uses uscan to check for new upstream releases
  class Watcher
    class NotKDESoftware < StandardError; end
    class UnstableURIForbidden < StandardError; end

    # Updates version info in snapcraft.yaml.
    # TODO: this maybe should also download the source and grab the desktop
    #   file & icon. Needs checking if snapcraft does grab this
    #   automatically yet, in which case we don't need to maintain copied data
    #   at all and instead have them extracted at build time.
    class SnapcraftUpdater
      def initialize(dehs)
        # TODO: this ungsub business is a bit meh. Maybe watcher should
        #   mangle the DEHS object and ungsub it right after parsing?
        @new_url = Watcher.ungsub_download_url(dehs.upstream_url)
        @new_version = dehs.upstream_version
        @snapcraft_yaml = 'snapcraft.yaml'
      end

      def run
        unless File.exist?(@snapcraft_yaml)
          puts "Snapcraft file #{@snapcraft_yaml} not found." \
               ' Skipping snapcraft logic.'
          return
        end
        snapcraft = YAML.load_file(@snapcraft_yaml)
        snapcraft = mangle(snapcraft)
        File.write(@snapcraft_yaml, YAML.dump(snapcraft, indentation: 4))
        puts 'Snapcraft updated.'
      end

      private

      def tar_basename_from_url(url)
        return url if url.nil?

        File.basename(url).reverse.split('-', 2).fetch(-1).reverse
      end

      def mangle(snapcraft)
        snapcraft['version'] = @new_version

        newest_tar = tar_basename_from_url(@new_url)
        snapcraft['parts'].each_value do |part|
          tar = tar_basename_from_url(part['source'])
          next unless tar == newest_tar

          part['source'] = @new_url
        end

        snapcraft
      end
    end

    attr_reader :cmd

    def initialize
      @cmd = TTY::Command.new
      cmd.run('git config --global --add safe.directory /workspace/deb-packaging')
    end

    # NB: this gets mocked by the test, don't merge this into regular cmd!
    # it allows us to only mock the uscan
    def uscan_cmd
      @uscan_cmd ||= TTY::Command.new
    end

    # KEEP IN SYNC with ungsub_download_url!
    def self.gsub_download_url(url)
      url.gsub('download.kde.org/', 'download.kde.internal.neon.kde.org/')
    end

    # KEEP IN SYNC with gsub_download_url!
    def self.ungsub_download_url(url)
      url.gsub('download.kde.internal.neon.kde.org/', 'download.kde.org/')
    end

    def job_is_kde_released
      # These parts get pre-released on server so don't pick them up
      # automatically
      @job_is_kde_released ||= begin
        released_products = KDEProjectsComponent.frameworks_jobs +
                            KDEProjectsComponent.plasma_jobs +
                            KDEProjectsComponent.gear_jobs
        job_project = ENV['JOB_NAME'].split('_')[-1]
        released_products.include?(job_project)
      end
    end

    def merge
      cmd.run!('git status')
      merged = false
      if cmd.run!('git merge origin/Neon/stable').success?
        merged = true
        # if it's a KDE project use only stable lines
        newer_stable = newer_dehs_packages.select do |x|
          x.upstream_url.include?('stable') &&
            x.upstream_url.include?('kde.org')
        end
        # mutates 🤮
        # FIXME: this is only necessary because we traditionally had multi-source watch files from the debian kde team.
        #   AFAIK these are no longer in use and also weren't really ever supported by uscan (perhaps uscan even
        #   dropped support?). There is an assertion that there is only a single dehs package in run. After a while
        #   if nothing exploded because of the assertion the multi-package support can be removed!
        @newer_dehs_packages = newer_stable unless newer_stable.empty?
      elsif cmd.run!('git merge origin/Neon/unstable').success?
        merged = true
        # Do not filter paths when unstable was merged. We use unstable as
        # common branch, so e.g. frameworks have only Neon/unstable but their
        # download path is http://download.kde.org/stable/frameworks/...
        # We thusly cannot kick stable.
      end
      raise 'Could not merge anything' unless merged
    end

    def with_mangle(&block)
      puts 'mangling debian/watch'
      output = ''
      FileUtils.cp('debian/watch', 'debian/watch.unmangled')
      File.open('debian/watch').each do |line|
        # The download.kde.internal.neon.kde.org domain is not
        # publicly available!
        # Only available through blue system's internal DNS.
        output += self.class.gsub_download_url(line)
      end
      puts output
      File.open('debian/watch', 'w') { |file| file.write(output) }
      puts 'mangled debian/watch'
      ret = yield
      puts 'unmangle debian/watch `git checkout debian/watch`'
      FileUtils.mv('debian/watch.unmangled', 'debian/watch')
      ret
    end

    def make_newest_dehs_package!
      newer = newer_dehs_packages.group_by(&:upstream_version)
      newer = Hash[newer.map { |k, v| [Debian::Version.new(k), v] }]
      newer = newer.sort.to_h
      newest = newer.keys[-1]
      @newest_version = newest
      @newest_dehs_package = newer.values[-1][0] # group_by results in an array

      raise 'No newest version found' unless newest_version && newest_dehs_package
    end

    def newer_dehs_packages
      @newer_dehs_packages ||= with_mangle do
        result = uscan_cmd.run!('uscan --report --dehs') # run! to ignore errors

        data = result.out
        puts "uscan exited (#{result}) :: #{data}"

        Debian::UScan::DEHS.parse_packages(data).collect do |package|
          next nil unless package.status == Debian::UScan::States::NEWER_AVAILABLE

          package
        end.compact
      end
    end

    # Set by bump_version. Fairly meh.
    def dch
      raise unless defined?(@dch)

      @dch
    end

    def bump_version
      changelog = Changelog.new(Dir.pwd)
      version = Debian::Version.new(changelog.version)
      version.upstream = newest_version
      version.revision = '0neon' unless version.revision.to_s.empty?
      @dch = Debian::Changelog.new_version_cmd(version.to_s, distribution: NCI.current_series, message: 'New release')
      # A bit awkward we want to give a dch suggestion in case this isn't kde software so we'll want to recycle
      # the command, meaning we can't just use changelog.new_version :|
      cmd.run(*dch)

      # --- Unset revision from this point on, so we get the base version ---
      version.revision = nil
      something_changed = false
      Dir.glob('debian/*') do |path|
        next unless path.end_with?('changelog', 'control', 'rules')
        next unless File.file?(path)

        data = File.read(path)
        begin
          # We track gsub results here because we'll later wrap-and-sort
          # iff something changed.
          source_change = data.gsub!('${source:Version}~ciBuild', version.to_s)
          binary_change = data.gsub!('${binary:Version}~ciBuild', version.to_s)
          something_changed ||= !(source_change || binary_change).nil?
        rescue StandardError => e
          raise "Failed to gsub #{path} -- #{e}"
        end
        File.write(path, data)
      end

      system('wrap-and-sort') if something_changed
    end

    attr_accessor :newest_version
    attr_accessor :newest_dehs_package

    def run
      raise 'No debian/watch found!' unless File.exist?('debian/watch')

      watch = File.read('debian/watch')
      if watch.include?('unstable') && watch.include?('download.kde.')
        raise UnstableURIForbidden, 'Quitting watcher as debian/watch contains unstable ' \
                                    'and we only build stable tars in Neon'
      end

      return if newer_dehs_packages.empty?

      # Message is transitional. The entire code in watcher is more complicated because of multiple packages.
      # e.g. see merge method.
      if newer_dehs_packages.size > 1
        raise 'There are multiple DEHS packages being reported. This suggests there are multiple sources in the watch' \
              " file. We'd like to get rid of these if possible. Check if we have full control over this package and" \
              ' drop irrelevant sources if possible. If we do not have full control check with upstream about the' \
              ' rationale for having multiple sources. If the source cannot be "fixed". Then remove this error and' \
              ' probably also check back with sitter.'
      end

      if job_is_kde_released && ENV['BUILD_CAUSE'] == "Started by timer"
        send_product_mail
        return
      end

      merge # this mutates newer_dehs_packages and MUST be before make_newest_dehs_package!
      make_newest_dehs_package! # sets a bunch of members - very awkwardly - must be after merge!

      job_project = ENV['JOB_NAME'].split('_')[-1]
      #if Dir.exist?("../snapcraft-kde-applications/#{job_project}")
        #Dir.chdir("../snapcraft-kde-applications/#{job_project}") do
          #SnapcraftUpdater.new(newest_dehs_package).run
          #cmd.run('git --no-pager diff')
          #cmd.run("git commit -a -vv -m 'New release'")
        #end
      #end

      bump_version

      cmd.run('git --no-pager diff')
      cmd.run("git commit -a -vv -m 'New release'")

      send_mail

      raise_if_not_kde_software!(dch)
    end

    def send_product_mail
      puts 'KDE Plasma/Gear/Framework watcher should be run manually not by timer, quitting'

      # Take first package from each product and send e-mail for only that
      # one to stop spam
      frameworks_package = KDEProjectsComponent.frameworks[0]
      plasma_package = KDEProjectsComponent.plasma[0]
      gear_package = KDEProjectsComponent.gear[0]
      product_packages = [frameworks_package, plasma_package, gear_package]
      return if product_packages.none? { |package| ENV['JOB_NAME'].end_with?("_#{package}") }

      puts 'sending notification mail'
      Pangea::SMTP.start do |smtp|
        mail = <<~MAIL
From: Neon CI <no-reply@kde.org>
To: neon-notifications@kde.org
Subject: #{ENV['JOB_NAME']} found a new PRODUCT BUNDLE version

New release found on the server but not building because it may not be public yet,
run jenkins_retry manually for this release on release day.
#{ENV['RUN_DISPLAY_URL']}
        MAIL
        smtp.send_message(mail,
                          'no-reply@kde.org',
                          'neon-notifications@kde.org')
      end
    end

    def send_mail
      return if ENV.key?('BUILD_CAUSE') and ENV['BUILD_CAUSE'] != 'Started by timer'

      subject = "Releasing: #{newest_dehs_package.name} - #{newest_version}"
      subject = "Dev Required: #{newest_dehs_package.name} - #{newest_version}" unless kde_software?

      puts 'sending notification mail'
      Pangea::SMTP.start do |smtp|
        mail = <<~MAIL
From: Neon CI <no-reply@kde.org>
To: neon-notifications@kde.org
Subject: #{subject}

#{ENV['RUN_DISPLAY_URL']}

#{newest_dehs_package.inspect}
        MAIL
        smtp.send_message(mail,
                          'no-reply@kde.org',
                          'neon-notifications@kde.org')
      end
    end

    def kde_software?
      job_is_kde_released || newest_dehs_package.upstream_url.include?('download.kde.') || newest_dehs_package.upstream_url.include?('invent.kde.')
    end

    def raise_if_not_kde_software!(dch)
      return if kde_software? # else we'll raise

      # Raise on none KDE software, they may not feature standard branch
      # layout etc, so tell a dev to deal with it.
      puts ''
      puts 'This is a non-KDE project. It never gets automerged or bumped!'
      puts 'Use dch to bump manually and merge as necessary, e.g.:'
      puts "git checkout Neon/release && git merge origin/Neon/stable && #{Shellwords.shelljoin(dch)} && git commit -a -m 'New release'"
      puts ''
      raise NotKDESoftware, 'New version available but not doing auto-bump!'
    end
  end
end
