# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'tty/command'
require 'httparty'

require_relative '../../lib/debian/version'
require_relative '../../lib/retry'

module NCI
  # Helper class for VersionsTest.
  # Implements the logic for a package version check. Takes a pkg
  # as input and then checks that the input's version is higher than
  # whatever is presently available in the apt cache (i.e. ubuntu or
  # the target neon repos).
  class PackageVersionCheck
    class VersionNotGreaterError < StandardError; end

    attr_reader :ours
    attr_reader :theirs

    def initialize(ours:, theirs:)
      @ours = ours
      @theirs = theirs
    end

    # Download and parse the neon-settings xenial->bionic pin override file
    def self.override_packages
      @@override_packages ||= begin
        url = "https://invent.kde.org/neon/neon/settings/-/raw/Neon/#{ENV.fetch('TYPE')}/etc/apt/preferences.d/99-#{NCI.future_series}-overrides?inline=false"
        response = HTTParty.get(url)
        response.parsed_response
        override_packages = []
        response.each_line do |line|
          match = line.match(/Package: (.*)/)
          override_packages << match[1] if match&.length == 2
        end
        override_packages
      end
    end

    def run
      # theirs can be nil if it doesn't exist on the 'their' side (e.g.
      #   we build a new deb and compare it against the repo, it'd be on our
      #   side but not theirs)
      # the version can be nil if theirs doesn't qualify to anything, when it is
      #   a pure virtual package for example
      return nil unless theirs&.version

      # Good version
      return if our_version > their_version
      PackageVersionCheck.override_packages
      return if @@override_packages.include?(ours.name) # already pinned in neon-settings

      raise VersionNotGreaterError, <<~ERRORMSG
        Our version of
        #{ours.name} #{our_version} < #{their_version}
        which is currently available in apt (likely from Ubuntu or us).
        This indicates that the package we have is out of date or
        regressed in version compared to a previous build!
        - If this was a transitional fork it needs removal in jenkins and the
          aptly.
        - If it is a persitent fork make sure to re-merge with upstream/ubuntu.
        - If someone manually messed up the version number discuss how to best
          deal with this. Usually this will need an apt pin being added to
          neon/settings.git to force it back onto a correct version, and manual
          removal of the broken version from aptly.
      ERRORMSG
    end

    private

    def our_version
      return ours.version if ours.version.is_a?(Debian::Version)

      Debian::Version.new(ours.version)
    end

    def their_version
      return theirs.version if theirs.version.is_a?(Debian::Version)

      Debian::Version.new(theirs.version)
    end
  end
end
