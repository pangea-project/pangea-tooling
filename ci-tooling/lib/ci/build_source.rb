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
    def initialize(release:, strip_symbols: false)
      @build_dir = "#{Dir.pwd}/build/"
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

    # Copies the source/ source tree into the target and strips it off a
    # possible debian/ directory.
    # @note this wipes @build_dir
    def copy_source
      # copy sources around
      FileUtils.rm_rf(@build_dir, verbose: true)
      copy_source_tree('source')
      if Dir.exist?("#{@build_dir}/source/debian")
        FileUtils.rm_rf(Dir.glob("#{@build_dir}/source/debian"))
      end
    end

    # Copies the packaging/ source tree into the target.
    # This overwrites files previously created by #{copy_source} if there are
    # name clashes.
    def copy_packaging
      # Copy some more
      copy_source_tree('packaging')
    end

    def create_orig_tar
      Dir.chdir(@build_dir) do
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

    def log_change
      # Create changelog entry
      Dir.chdir("#{@build_dir}/source/") do
        ENV['DEBFULLNAME'] = @data[@flavor][:name]
        ENV['DEBEMAIL'] = @data[@flavor][:email]
        create_changelog_entry
      end
    end

    def build
      # dpkg-buildpackage
      Dir.chdir("#{@build_dir}/source/") do
        system('update-maintainer')
        # Force -sa as reprepreo refuses to accept uploads without orig.
        unless system('dpkg-buildpackage', '-us', '-uc', '-S', '-d', '-sa')
          raise 'Could not run dpkg-buildpackage!'
        end
      end

      Dir.chdir(@build_dir) do
        dsc = Dir.glob('*.dsc')
        raise 'Exactly one dsc not found' if dsc.size != 1
        @source.dsc = dsc[0]
      end

      @version_enforcer.record!(@source.version)
    end

    def cleanup
      FileUtils.rm_rf("#{@build_dir}/source")
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

    def create_changelog_entry
      dch = [
        'dch',
        '--force-bad-version',
        '--distribution', @release,
        '--newversion', @source.version,
        "Automatic #{@flavor.capitalize} CI Build"
      ]
      # dch cannot actually fail because we parse the changelog beforehand
      # so it is of acceptable format here already.
      raise 'Failed to create changelog entry' unless system(*dch)
    end

    # Copies a source tree to the target source directory
    # @param source_dir the directory to copy from (all content within will
    #   be copied)
    # @note this will create @build_dir/source if it doesn't exist
    # @note this will strip the copied source of version control directories
    def copy_source_tree(source_dir)
      FileUtils.mkpath("#{@build_dir}/source")
      if Dir.exist?(source_dir)
        # /. is fileutils notation for recursive content
        FileUtils.cp_r("#{source_dir}/.",
                       "#{@build_dir}/source/",
                       verbose: true)
      end
      %w(.bzr .git .hg .svn).each do |dir|
        FileUtils.rm_rf(Dir.glob("#{@build_dir}/source/**/#{dir}"))
      end
    end

    def mangle_manpages(file)
      # Strip localized manpages
      # e.g.  usr /share /man /  *  /man 7 /kf5options.7
      man_regex = %r{^.*usr/share/man/(\*|\w+)/man\d/.*$}
      subbed = File.open(file).read.gsub(man_regex, '')
      File.write(file, subbed)
    end

    def mangle_locale(file)
      locale_regex = %r{^.*usr/share/locale.*$}
      subbed = File.open(file).read.gsub(locale_regex, '')
      File.write(file, subbed)
    end

    def mangle_lintian_of(file)
      return unless File.open(file, 'r').read.strip.empty?
      package_name = File.basename(file, '.install')
      lintian_overrides_path = file.gsub('.install', '.lintian-overrides')
      puts "#{package_name} is now empty, trying to add lintian override"
      File.open(lintian_overrides_path, 'a') do |f|
        f.write("#{package_name}: empty-binary-package\n")
      end
    end

    def mangle_install_file(file)
      mangle_manpages(file)
      # FIXME: bloody workaround for kconfigwidgets, kdelibs4support
      # and ubuntu-ui-toolkit containing legit locale data
      if %w(kconfigwidgets
            kdelibs4support
            ubuntu-ui-toolkit).include?(@source.name)
        return
      end
      mangle_locale(file)
      # If the package is now empty, lintian override the empty warning
      # to avoid false positives
      mangle_lintian_of(file)
    end

    def mangle_symbols
      # Rip out symbol files unless we are on latest
      if @strip_symbols || @release != KCI.latest_series
        symbols = Dir.glob('debian/symbols') +
                  Dir.glob('debian/*.symbols') +
                  Dir.glob('debian/*.symbols.*')
        symbols.each { |s| FileUtils.rm(s) }
      end
    end

    def mangle!
      # Rip out locale install
      Dir.chdir("#{@build_dir}/source/") do
        Dir.glob('debian/*.install').each do |install_file_path|
          mangle_install_file(install_file_path)
        end
        mangle_symbols
      end
    end
  end
end
