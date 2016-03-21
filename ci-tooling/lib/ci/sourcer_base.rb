# frozen_string_literal: true
#
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
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

require 'date'
require 'fileutils'
require 'yaml'

require_relative '../debian/changelog'
require_relative '../debian/source'
require_relative '../kci'
require_relative '../os'
require_relative 'build_version'
require_relative 'source'
require_relative 'version_enforcer'

module CI
  class SourcerBase
    private

    def initialize(release:, strip_symbols:)
      @release = release # e.g. vivid
      @strip_symbols = strip_symbols

      # vcs
      @packaging_dir = File.absolute_path('packaging').freeze
      # orig
      @packagingdir = @packaging_dir.freeze

      # vcs
      @build_dir = "#{Dir.pwd}/build".freeze
      # orig
      @builddir = @build_dir.freeze
      FileUtils.rm_r(@build_dir) if Dir.exist?(@build_dir)
      Dir.mkdir(@build_dir)

      # vcs
      # TODO:
      # orig
      @sourcepath = "#{@builddir}/source" # Created by extract.
    end

    def create_changelog_entry(version, message = 'Automatic CI Build')
      dch = [
        'dch',
        '--force-bad-version',
        '--distribution', @release,
        '--newversion', version,
        message
      ]
      # dch cannot actually fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      raise 'Failed to create changelog entry' unless system(*dch)
    end

    def dpkg_buildpackage
      system('update-maintainer')
      args = [
        'dpkg-buildpackage',
        '-us', '-uc', # Do not sign .dsc / .changes
        '-S', # Only build source
        '-d' # Do not enforce build-depends
      ]
      raise 'Could not run dpkg-buildpackage!' unless system(*args)
    end
  end
end
