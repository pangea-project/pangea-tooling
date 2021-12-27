# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

require 'date'

require_relative '../os'
require_relative '../debian/changelog'

module CI
  # Wraps a debian changelog to construct a build specific version based on the
  # version used in the changelog.
  class BuildVersion
    TIME_FORMAT = '%Y%m%d.%H%M'

    # Version (including epoch)
    attr_reader :base
    # Version (excluding epoch)
    attr_reader :tar
    # Version include epoch AND possibly a revision
    attr_reader :full

    def initialize(changelog)
      @changelog = changelog
      @suffix = format('+p%<os_version>s+t%<type>s+git%<time>s',
                       os_version: version_id, type: version_type, time: time)
      @tar = "#{clean_base}#{@suffix}"
      @base = "#{changelog.version(Changelog::EPOCH)}#{clean_base}#{@suffix}"
      @full = "#{base}-0"
    end

    # Version (including epoch AND possibly a revision)
    def to_s
      full
    end

    private

    def version_type
      # Make sure the TYPE doesn't have a hyphen. If this guard should fail you have to
      # figure out what to do with it. e.g. it could become a ~ and consequently lose to similarly named
      # type versions.
      raise if ENV.fetch('TYPE').include?('-')

      ENV.fetch('TYPE')
    end

    # Helper to get the time string for use in the version
    def time
      DateTime.now.strftime(TIME_FORMAT)
    end

    # Removes non digits from base version string.
    # This is to get rid of pesky alphabetic suffixes such as 5.2.2a which are
    # lower than 5.2.2+git (which we might have used previously), as + reigns
    # supreme. Always.
    def clean_base
      base = @changelog.version(Changelog::BASE)
      base = base.chop until base.empty? || base[-1].match(/[\d\.]/)
      return base unless base.empty?

      raise 'Failed to find numeric version in the changelog version:' \
           " #{@changelog.version(Changelog::BASE)}"
    end

    def version_id
      if OS.to_h.key?(:VERSION_ID)
        id = OS::VERSION_ID
        return OS::VERSION_ID unless id.nil? || id.empty?
      end

      return '10' if OS::ID == 'debian'

      raise 'VERSION_ID not defined!'
    end
  end
end
