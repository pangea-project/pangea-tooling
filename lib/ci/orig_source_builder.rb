# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

require 'fileutils'

require_relative '../debian/changelog'
require_relative '../lsb'
require_relative '../os'
require_relative 'sourcer_base'

module CI
  # Builds a source package from an existing tarball.
  class OrigSourceBuilder < SourcerBase
    def initialize(release: LSB::DISTRIB_CODENAME, strip_symbols: false,
                   restricted_packaging_copy: false)
      super

      # @name
      # @version
      # @tar

      @release_version = "#{OS::VERSION_ID}+#{ENV.fetch('DIST')}"
      @build_rev = ENV.fetch('BUILD_NUMBER')

      # FIXME: builder should generate a Source instance
    end

    def build(tarball)
      FileUtils.cp(tarball.path, @builddir, verbose: true)
      tarball.extract(@sourcepath)

      args = [] << 'debian' if @restricted_packaging_copy
      copy_source_tree(@packagingdir, *args)

      Dir.chdir(@sourcepath) do
        log_change
        mangle!
        build_internal
      end
    end

    private

    def log_change
      # FIXME: this has email and fullname from env, see build_source
      changelog = Changelog.new
      raise "Can't parse changelog!" unless changelog

      base_version = changelog.version
      if base_version.include?('ubuntu')
        base_version = base_version.split('ubuntu')
        base_version = base_version[0..-2].join('ubuntu')
      end
      # Make sure our version exceeds Ubuntu's by prefixing us with an x.
      # This way -0xneon > -0ubuntu instead of -0neon < -0ubuntu
      base_version = base_version.gsub('neon', 'xneon')
      base_version = "#{base_version}+#{@release_version}#{build_suffix}"
      changelog.new_version!(base_version, distribution: @release, message: 'Automatic CI Build')
    end

    def build_suffix
      suffix = "+build#{@build_rev}"
      return suffix unless ENV.fetch('TYPE') == 'experimental'

      # Prepend and experimental qualifier to **lower** the version beyond
      # whatever can be in unstable. This act as a safe guard should the
      # build rev in experimental (the repo where we stage Qt) become greater
      # then the build rev in unstable (the repo where we regularly build Qt).
      # This allows us to copy packages from experimental without fear of their
      # build number outranking future unstable builds.
      # NB: this qualifier MUST BE EXACTLY BEFORE the build qualifier, it should
      #   not impact anything but the build number.
      "~exp#{suffix}"
    end

    def mangle!
      mangle_symbols
    end

    def build_internal
      Dir.chdir(@sourcepath) { dpkg_buildpackage }
    end
  end
end
