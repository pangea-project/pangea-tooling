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

      @release_version = case release
                         when 'testing'
                           '9'
                         else
                           OS::VERSION_ID
                         end
      @build_rev = ENV.fetch('BUILD_NUMBER')

      # FIXME: builder should generate a Source instance
    end

    def build(tarball)
      FileUtils.cp(tarball.path, @builddir)
      tarball.extract(@sourcepath)
      FileUtils.cp_r(Dir.glob("#{@packagingdir}/*"), @sourcepath)
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
      base_version = "#{base_version}+#{@release_version}+build#{@build_rev}"
      create_changelog_entry(base_version)
    end

    def mangle!
      mangle_symbols
    end

    def build_internal
      Dir.chdir(@sourcepath) { dpkg_buildpackage }
    end
  end
end
