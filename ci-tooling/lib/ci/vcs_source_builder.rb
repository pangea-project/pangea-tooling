# frozen_string_literal: true
#
# Copyright (C) 2015 Rohan Garg <rohan@garg.io>
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
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
require 'yaml'

require_relative '../apt'
require_relative '../debian/changelog'
require_relative '../debian/source'
require_relative '../os'
require_relative 'build_version'
require_relative 'source'
require_relative 'sourcer_base'
require_relative 'version_enforcer'

module CI
  # Extend VCS builder with l10n functionality based on releaseme.
  # NOTE: super experimental right now!
  module SourceBuilderL10nExtension
    class << self
      def enable_l10n_injection
        @l10n_injection_disabled = false
      end

      def disable_l10n_injection
        @l10n_injection_disabled = true
      end

      def l10n_injection_disabled?
        @l10n_injection_disabled ||= false
      end
    end

    def l10n_log
      @l10n_log ||= Logger.new(STDOUT).tap { |l| l.progname = 'l10n' }
    end

    def copy_source_tree(*args)
      ret = super
      disabled = SourceBuilderL10nExtension.l10n_injection_disabled?
      unless %w(unstable stable).include?(ENV.fetch('TYPE', '')) && !disabled
        l10n_log.info 'Not doing l10n injection.'
        l10n_log.info "Job type #{ENV.fetch('TYPE', '')} | #{disabled}"
        return ret
      end
      inject_l10n!("#{@build_dir}/source/") if args[0] == 'source'
      ret
    end

    private

    def inject_releaseme?
      `git clone git://anongit.kde.org/releaseme.git`
      return $?.success? unless $?.success?
      require "#{Dir.pwd}/releaseme/lib/releaseme"
      true
    end

    def enabled_project?(project)
      %w(kde-workspace frameworks).include?(project.i18n_path)
    end

    def with_releaseme(&_block)
      Apt.install('subversion') || raise
      Dir.mktmpdir do |tmpdir|
        Dir.chdir(tmpdir) do
          break unless inject_releaseme?
          yield
        end
      end
    end

    def project_for_name(repo_name)
      projects = ReleaseMe::Project.from_xpath(repo_name.gsub('.git', ''))
      unless projects.size == 1
        raise "failed to resolve project #{repo_name} :: #{projects}"
      end
      projects[0]
    end

    def l10n_origin
      {
        'unstable' => ReleaseMe::Origin::TRUNK,
        'stable' => ReleaseMe::Origin::STABLE
      }.fetch(ENV.fetch('TYPE'))
    end

    # Add l10n to source dir
    def add_l10n(source_path, repo_url)
      project = project_for_name(File.basename(repo_url))
      return unless enabled_project?(project)

      ENV['RELEASEME_DEBUG'] = 'true'
      l10n = ReleaseMe::L10n.new(l10n_origin, project.identifier,
                                 project.i18n_path)
      l10n.default_excluded_languages = []
      l10n.get(source_path)

      (class << self; self; end).class_eval do
        define_method(:mangle_locale) { |*| } # disable mangling
      end
    end

    def repo_url_from_path(path)
      return nil unless Dir.exist?(path)
      require 'rugged'
      repo = Rugged::Repository.discover(path)
      remote = repo.remotes['upstream'] if repo
      url = remote.url if remote && remote.url.include?('.kde.org')
      url || nil
    end

    def inject_l10n!(source_path)
      # This is ./source, while path is ./build/source
      url = repo_url_from_path('source')
      l10n_log.info "l10n injection for url #{url}."
      return unless url
      # TODO: this would benefit from classing
      with_releaseme { add_l10n(source_path, url) }
    end
  end

  # Class to build out source package from a VCS
  class VcsSourceBuilder < SourcerBase
    prepend SourceBuilderL10nExtension

    def initialize(release:, strip_symbols: false,
                   restricted_packaging_copy: false)
      super
      # FIXME: use packagingdir and sourcedir
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

    def create_orig_tar
      Dir.chdir(@build_dir) do
        tar = "#{@source.name}_#{@tar_version}.orig.tar"
        raise 'Failed to create orig tar' unless system("tar -cf #{tar} source")
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
        create_changelog_entry(@source.version,
                               "Automatic #{@flavor.capitalize} CI Build")
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
