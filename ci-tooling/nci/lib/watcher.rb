# frozen_string_literal: true

# SPDX-FileCopyrightText: 2016-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'pp'

require_relative '../../lib/debian/changelog'
require_relative '../../lib/debian/uscan'
require_relative '../../lib/debian/version'
require_relative '../../lib/nci'

require_relative '../../../lib/kdeproject_component'
require_relative '../../../lib/pangea/mail'

require 'shellwords'
require 'tty-command'

module NCI
  # uses uscan to check for new upstream releases
  class Watcher
    class NotKDESoftware < StandardError; end

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

    # Env variables which reflect jenkins trigger causes
    CAUSE_ENVS = %w[BUILD_CAUSE ROOT_BUILD_CAUSE].freeze
    # Key word for manually triggered builds
    MANUAL_CAUSE = 'MANUALTRIGGER'

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

    def run
      raise 'No debain/watch found!' unless File.exist?('debian/watch')

      puts 'mangling debian/watch'
      output = ''
      File.open('debian/watch').each do |line|
        # The download.kde.internal.neon.kde.org domain is not
        # publicly available!
        # Only available through blue system's internal DNS.
        output += self.class.gsub_download_url(line)
      end
      puts output
      File.open('debian/watch', 'w') { |file| file.write(output) }
      puts 'mangled debian/watch'

      if File.read('debian/watch').include?('unstable')
        puts 'Quitting watcher as debian/watch contains unstable ' \
             'and we only build stable tars in Neon'
        return
      end

      result = uscan_cmd.run!('uscan --report --dehs') # run! to ignore errors
      data = result.out
      puts "uscan exited (#{result}) :: #{data}"

      newer = Debian::UScan::DEHS.parse_packages(data).collect do |package|
        next nil unless package.status == Debian::UScan::States::NEWER_AVAILABLE

        package
      end.compact
      pp newer

      return if newer.empty?

      puts 'unmangle debian/watch `git checkout debian/watch`'
      system('git checkout debian/watch')

      job_is_kde = ENV.fetch('JOB_NAME').include?('_kde_')

      # These parts get pre-released on server so don't pick them up
      # automatically
      if job_is_kde && CAUSE_ENVS.any? { |v| ENV[v] == 'TIMERTRIGGER' }
        puts 'KDE Plasma/Releases/Framework watcher should be run manually not by '\
             'timer, quitting'
        puts 'sending notification mail'
        # Take first package from each product and send e-mail for only that
        # one to stop spam
        frameworks_package = KDEProjectsComponent.frameworks[0]
        plasma_package = KDEProjectsComponent.plasma[0]
        release_service_package = KDEProjectsComponent.release_service[0]
        kde_products = [frameworks_package, plasma_package, \
                        release_service_package]
        if kde_products.any? { |package| ENV['JOB_NAME'].include?("_#{package}") }
          Pangea::SMTP.start do |smtp|
            mail = <<-MAIL
From: Neon CI <no-reply@kde.org>
To: neon-notifications@kde.org
Subject: #{ENV['JOB_NAME']} found a new version

New release found on the server but not building because it may not be public yet,
run jenkins_retry manually for this release on release day.
#{ENV['RUN_DISPLAY_URL']}
            MAIL
            smtp.send_message(mail,
                              'no-reply@kde.org',
                              'neon-notifications@kde.org')
          end
        end
        return
      end

      cmd = TTY::Command.new
      cmd.run!('git status')
      merged = false
      if cmd.run!('git merge origin/Neon/stable').success?
        merged = true
        # if it's a KDE project use only stable lines
        newer_stable = newer.select do |x|
          x.upstream_url.include?('stable') && \
            x.upstream_url.include?('kde.org')
        end
        newer = newer_stable unless newer_stable.empty?
      elsif cmd.run!('git merge origin/Neon/unstable').success?
        merged = true
        # Do not filter paths when unstable was merged. We use unstable as
        # common branch, so e.g. frameworks have only Neon/unstable but their
        # download path is http://download.kde.org/stable/frameworks/...
        # We thusly cannot kick stable.
      end
      raise 'Could not merge anything' unless merged

      newer = newer.group_by(&:upstream_version)
      newer = Hash[newer.map { |k, v| [Debian::Version.new(k), v] }]
      newer = newer.sort.to_h
      newest = newer.keys[-1]
      newest_dehs = newer.values[-1][0] # is 1 size'd Array because of group_by
      newest_dehs_package = newer.values[-1][0] # group_by results in an array

      puts "newest #{newest.inspect}"
      p newest_dehs_package.to_s
      raise 'No newest version found' unless newest

      version = Debian::Version.new(Changelog.new(Dir.pwd).version)
      version.upstream = newest
      version.revision = '0neon' unless version.revision.to_s.empty?

      # FIXME: stolen from sourcer
      dch = [
        'dch',
        '--distribution', NCI.current_series,
        '--newversion', version.to_s,
        'New release'
      ]
      # dch cannot actually fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      raise 'Failed to create changelog entry' unless system(*dch)

      # FIXME: almost code copy from sourcer_base
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

      SnapcraftUpdater.new(newest_dehs).run

      system('wrap-and-sort') if something_changed

      puts 'git diff'
      system('git --no-pager diff')
      puts "git commit -a -m 'New release'"
      system("git commit -a -m 'New release'")

      puts ENV.to_h

      if CAUSE_ENVS.none? { |v| ENV[v] == MANUAL_CAUSE }
        puts 'sending notification mail'
        Pangea::SMTP.start do |smtp|
          mail = <<-MAIL
  From: Neon CI <no-reply@kde.org>
  To: neon-notifications@kde.org
  Subject: #{newest_dehs_package.name} new version #{newest}

  #{ENV['RUN_DISPLAY_URL']}

  #{newest_dehs_package.inspect}
          MAIL
          smtp.send_message(mail,
                            'no-reply@kde.org',
                            'neon-notifications@kde.org')
        end
      end

      if job_is_kde ||
         newest_dehs_package.upstream_url.include?('download.kde.org')
        return
      end

      # Raise on none KDE software, they may not feature standard branch
      # layout etc, so tell a dev to deal with it.
      puts ''
      puts 'This is a non-KDE project. It never gets automerged or bumped!'
      puts 'Use dch to bump manually and merge as necessary, e.g.:'
      puts "#{Shellwords.shelljoin(dch)} && git commit -a -m 'New release'"
      puts ''
      raise NotKDESoftware, 'New version available but not doing auto-bump!'
    end
  end
end
