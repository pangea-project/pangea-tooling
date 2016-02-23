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
  # Class to build out source package from a VCS
  class VcsSourceBuilder
    BUILD_DIR = 'build/'.freeze

    def initialize(release:, strip_symbols: false)
      @release = release # e.g. vivid
      @flavor = OS::ID.to_sym # e.g. Ubuntu
      @data = YAML.load_file("#{__dir__}/data/maintainer.yaml")

      @source = CI::Source.new
      changelog = nil
      Dir.chdir('packaging') do
        @source.type = Debian::Source.new(Dir.pwd).format.type
        changelog = Changelog.new
        raise "Can't parse changelog!" if changelog.nil?
      end

      @source.name = changelog.name
      @source.build_version = CI::BuildVersion.new(changelog)
      @source.version = if @source.type == :native
                          @source.build_version.base
                        else
                          @source.build_version.full
                        end

      @tar_version = @source.build_version.tar
      @strip_symbols = strip_symbols

      @version_enforcer = VersionEnforcer.new
      @version_enforcer.validate(@source.version)
    end

    def copy_source
      # copy sources around
      FileUtils.rm_rf(BUILD_DIR, verbose: true)

      # Allow support for format 1.0 and quilt
      source_dir = 'source'

      FileUtils.mkpath("#{BUILD_DIR}/source")
      # Legacy behavior was to ignore missing source directories. Using the
      # fileutils /. notation does not allow for this though.
      # FIXME: deprecate away from this and let missing sources fail!
      #   if a native doesn't have packaging or a non-native no source that is
      #   rather a problem
      if Dir.exist?(source_dir)
        # NOTE: /. is fileutils notation for recursive content
        FileUtils.cp_r("#{source_dir}/.", "#{BUILD_DIR}/source/", verbose: true)
      end

      %w(.bzr .git .hg .svn debian).each do |dir|
        FileUtils.rm_rf(Dir.glob("#{BUILD_DIR}/source/**/#{dir}"))
      end
    end

    def create_orig_tar
      Dir.chdir(BUILD_DIR) do
        tar = "#{@source.name}_#{@tar_version}.orig.tar"
        unless system("tar -cf #{tar} source")
          raise 'Failed to create a tarball'
        end
        r = system("pxz -6 #{tar}")
        unless r
          warn 'Falling back to slower single threaded compression'
          raise 'Failed to compress the tarball' unless system("xz -6 #{tar}")
        end
      end
    end

    def copy_packaging
      # Copy some more
      FileUtils.cp_r('packaging/debian', 'build/source/', verbose: true)
    end

    def log_change
      # Create changelog entry
      Dir.chdir("#{BUILD_DIR}/source/") do
        ENV['DEBFULLNAME'] = @data[@flavor][:name]
        ENV['DEBEMAIL'] = @data[@flavor][:email]
        unless system("dch -b -v #{@source.version} -D #{@release} \
                      'Automatic #{@flavor.capitalize} CI Build'")
          # :nocov:
          # dch cannot actually fail because we parse the changelog beforehand
          # so it is of acceptable format here already.
          raise 'Failed to create changelog entry'
          # :nocov:
        end
      end
    end

    def build
      # dpkg-buildpackage
      Dir.chdir("#{BUILD_DIR}/source/") do
        system('update-maintainer')
        # Force -sa as reprepreo refuses to accept uploads without orig.
        unless system('dpkg-buildpackage', '-us', '-uc', '-S', '-d', '-sa')
          raise 'Could not run dpkg-buildpackage!'
        end
      end

      Dir.chdir(BUILD_DIR) do
        dsc = Dir.glob('*.dsc')
        raise 'Exactly one dsc not found' if dsc.size != 1
        @source.dsc = dsc[0]
      end

      @version_enforcer.record!(@source.version)
    end

    def cleanup
      FileUtils.rm_rf("#{BUILD_DIR}/source")
    end

    def run
      copy_source
      create_orig_tar
      copy_packaging
      mangle!
      log_change
      build
      cleanup
      @source
    end

    private

    def mangle!
      # Rip out locale install
      Dir.chdir('build/source/') do
        Dir.glob('debian/*.install').each do |install_file_path|
          # Strip localized manpages
          # e.g.  usr /share /man /  *  /man 7 /kf5options.7
          man_regex = %r{^.*usr/share/man/(\*|\w+)/man\d/.*$}
          subbed = File.open(install_file_path).read.gsub(man_regex, '')
          File.open(install_file_path, 'w') do |f|
            f << subbed
          end

          # FIXME: bloody workaround for kconfigwidgets, kdelibs4support
          # and ubuntu-ui-toolkit containing legit locale data
          if %w(kconfigwidgets
                kdelibs4support
                ubuntu-ui-toolkit).include?(@source.name)
            next
          end

          locale_regex = %r{^.*usr/share/locale.*$}
          subbed = File.open(install_file_path).read.gsub(locale_regex, '')
          File.open(install_file_path, 'w') do |f|
            f << subbed
          end
        end
        # If the package is now empty, lintian override the empty warning
        # to avoid false positives
        Dir.glob('debian/*.install').each do |install_file_path|
          next unless File.open(install_file_path, 'r').read.strip.empty?
          package_name = File.basename(install_file_path, '.install')
          lintian_overrides_path = install_file_path.gsub('.install',
                                                          '.lintian-overrides')
          puts "#{package_name} is now empty, trying to add lintian override"
          File.open(lintian_overrides_path, 'a') do |file|
            file.write("#{package_name}: empty-binary-package\n")
          end
        end
        # Rip out symbol files unless we are on latest
        if @strip_symbols || @release != KCI.latest_series
          symbols = Dir.glob('debian/symbols') +
                    Dir.glob('debian/*.symbols') +
                    Dir.glob('debian/*.symbols.*')
          symbols.each { |s| FileUtils.rm(s) }
        end
      end
    end
  end
end
