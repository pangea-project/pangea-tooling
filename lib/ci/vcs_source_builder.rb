# frozen_string_literal: true
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL
# SPDX-FileCopyrightText: 2015 Rohan Garg <rohan@garg.io>
# SPDX-FileCopyrightText: 2015-2021 Harald Sitter <sitter@kde.org>

# TODO: merge various names for sourcing. This acts a require guard.
#   Regular require load the file twice
#   as it doesn't consider the real file and its compat symlink different
#   so the monkey patch would get applied multiple times breaking the orig
#   alias.
return if defined?(VCS_SOURCE_BUILDER_REQUIRE_GUARD)

VCS_SOURCE_BUILDER_REQUIRE_GUARD = true

require 'fileutils'
require 'yaml'

require_relative '../tty_command'
require_relative '../apt'
require_relative '../debian/changelog'
require_relative '../debian/source'
require_relative '../os'
require_relative 'build_version'
require_relative 'source'
require_relative 'sourcer_base'
require_relative 'version_enforcer'
module CI

  # Class to build out source package from a VCS
  class VcsSourceBuilder < SourcerBase

    def initialize(release:, strip_symbols: false,
                   restricted_packaging_copy: false)
      super
      # FIXME: use packagingdir and sourcedir
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

      @version_enforcer = VersionEnforcer.new
      @version_enforcer.validate(@source.version)
    end

    # Copies the source/ source tree into the target and strips it off a
    # possible debian/ directory.
    # @note this wipes @build_dir
    def copy_source
      copy_source_tree('source')
      return unless Dir.exist?("#{@build_dir}/source/debian")

      FileUtils.rm_rf(Dir.glob("#{@build_dir}/source/debian"))
    end

    # Copies the packaging/ source tree into the target.
    # This overwrites files previously created by #{copy_source} if there are
    # name clashes.
    def copy_packaging
      # Copy some more
      args = [] << 'debian' if @restricted_packaging_copy
      copy_source_tree('packaging', *args)
    end

    def compression_level
      return '-0' if ENV['PANGEA_UNDER_TEST']

      '-6'
    end

    def tar_it(origin, xzfile)
      # Try to compress using all cores, if that fails fall back to serial.
      cmd = TTY::Command.new
      cmd.run({ 'XZ_OPT' => "--threads=0 #{compression_level}" },
              'tar', '-cJf', xzfile, origin)
    rescue TTY::Command::ExitError
      warn 'Tar fail. Falling back to slower single threaded compression...'
      cmd.run({ 'XZ_OPT' => compression_level },
              'tar', '-cJf', xzfile, origin)
    end

    def create_orig_tar
      Dir.chdir(@build_dir) do
        tar_it('source', "#{@source.name}_#{@tar_version}.orig.tar.xz")
      end
    end

    def build
      # dpkg-buildpackage
      Dir.chdir("#{@build_dir}/source/") { dpkg_buildpackage }

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

    def log_change
      # Create changelog entry
      Debian::Changelog.new_version!(@source.version, distribution: @release,
                                                      message: "Automatic #{OS::ID.capitalize} CI Build",
                                                      chdir: "#{@build_dir}/source/")
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
      if %w[kconfigwidgets
            kdelibs4support
            ubuntu-ui-toolkit
            ubuntu-release-upgrader-neon].include?(@source.name)
        return
      end

      # Do not mange locale in .install now they are brought into Git by scripty
      #mangle_locale(file)
      # If the package is now empty, lintian override the empty warning
      # to avoid false positives
      mangle_lintian_of(file)
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
