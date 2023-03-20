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
require 'releaseme'
require 'yaml'

# for releasem ftp vcs
require 'concurrent'
require 'net/ftp'
require 'net/ftp/list'

require_relative '../tty_command'
require_relative '../apt'
require_relative '../debian/changelog'
require_relative '../debian/source'
require_relative '../os'
require_relative 'build_version'
require_relative 'source'
require_relative 'sourcer_base'
require_relative 'version_enforcer'

module ReleaseMe
  # SVN replacement hijacks svn and redirects to ftp intead
  # this isn't tested because testing ftp is a right headache.
  # Be very careful with rescuing errors, due to the lack of testing
  # rescuing must be veeeeeeery carefully done.
  class FTP < Vcs
    def initialize
      @svn = Svn.allocate
      @thread_storage ||= Concurrent::Hash.new
    end

    def clean!(*)
      # already clean with ftp, there's no temporary cache on-disk
    end

    def ftp
      # this is kinda thread safe in that Thread.current cannot change out from
      # under us, and the storage is a concurrent hash.
      @thread_storage[Thread.current] ||= begin
        uri = URI.parse(repository)
        ftp = Net::FTP.new(uri.host, port: uri.port)
        ftp.login
        ftp.chdir(uri.path)
        ftp
      end
    end

    def cat(file_path)
      ftp.get(file_path, nil)
    end

    def export(target, path)
      ftp.get(path, target)
    rescue Net::FTPPermError => e
      FileUtils.rm_f(target) # git ignorantly touches the file before trying to read -.-
      false
    end

    def get_r(ftp, target, path)
      any = false
      ftp.list(path).each do |e|
        entry = Net::FTP::List.parse(e)
        entry_path = File.join(path, entry.basename)
        target_path = File.join(target, entry.basename)
        if entry.file?
          FileUtils.mkpath(File.dirname(target_path))
          ftp.get(entry_path, target_path)
        elsif entry.dir?
          get_r(ftp, target_path, entry_path)
        else
          raise "Unsupported entry #{entry} #{entry.inspect}"
        end
        any = true
      end
      any
    end

    def get(target, path = nil, clean: false)
      get_r(ftp, target, path)
    end

    def list(path = nil)
      ftp.nlst(path).join("\n")
    end

    def method_missing(symbol, *arguments, &block)
      if @svn.respond_to?(symbol)
        raise "#{symbol} not implemented by #{self.class} overlay for SVN"
      end

      super
    end

    def respond_to_missing?(symbol, include_private = false)
      @svn.respond_to?(symbol, include_private) || super
    end
  end
end

module CI
  # Extend a builder with l10n functionality based on releaseme.
  module SourceBuilderL10nExtension
    # Hijack this when working on source to inject the l10n into the copied
    # source BUT not the git repo source. This prevents us from polluting the
    # possibly later reused git clone.
    def copy_source_tree(*args)
      ret = super
      unless ENV['TYPE'] == 'nol10n' # used in tests
        inject_l10n!("#{@build_dir}/source/") if args[0] == 'source'
      end
      ret
    end

    private

    def l10n_log
      @l10n_log ||= Logger.new(STDOUT).tap { |l| l.progname = 'l10n' }
    end

    def project_for_url(url)
      projects = ReleaseMe::Project.from_repo_url(url.gsub(/\.git$/, ''))
      unless projects.size == 1
        raise "failed to resolve project #{url} :: #{projects}"
      end

      projects[0]
    end

    def l10n_origin_from_type
      {
        'desktop' => ReleaseMe::Origin::TRUNK,
        'core' => ReleaseMe::Origin::TRUNK,
        'c1' => ReleaseMe::Origin::TRUNK,
        'z1' => ReleaseMe::Origin::TRUNK,
        'z2' => ReleaseMe::Origin::TRUNK,
        'unstable' => ReleaseMe::Origin::TRUNK,
        'stable' => ReleaseMe::Origin::STABLE,
        'release' => ReleaseMe::Origin::STABLE
      }.fetch(ENV.fetch('TYPE'))
    end

    def l10n_origin_for(project)
      origin = l10n_origin_from_type

      # TODO: ideally we should pass the BRANCH from the master job into
      #   the sourcer job and assert that the upstream branch is the stable/
      #   trunk branch which is set here. This would assert that the
      #   upstream_scm used to create the jobs was in sync with the data we see.
      #   If it was not this is a fatal problem as we might be integrating
      #   incorrect translations.
      if origin == ReleaseMe::Origin::STABLE && !project.i18n_stable
        warn 'This project has no stable branch. Falling back to trunk.'
        origin = ReleaseMe::Origin::TRUNK
      end

      if origin == ReleaseMe::Origin::TRUNK && !project.i18n_trunk
        raise 'Project has no i18n trunk WTF. This should not happen.'
      end

      origin
    end

    # Add l10n to source dir
    def add_l10n(source_path, repo_url)
      project = project_for_url(repo_url)

      # Use the pangea mirror (exclusively mirrors l10n messages) to avoid
      # too low connection limits on the regular KDE server.
      ENV['RELEASEME_SVN_REPO_URL'] = 'ftp://files.kde.mirror.pangea.pub:21012'
      l10n = ReleaseMe::L10n.new(l10n_origin_for(project), project.identifier,
                                 project.i18n_path, vcs: ReleaseMe::FTP.new)
      l10n.default_excluded_languages = [] # Include even x-test.
      l10n.get(source_path)
      l10n.vcs.clean!("#{source_path}/po")

      (class << self; self; end).class_eval do
        define_method(:mangle_locale) { |*| } # disable mangling
      end
    end

    def repo_url_from_path(path)
      return nil unless Dir.exist?(path)

      require 'rugged'
      repo = Rugged::Repository.discover(path)
      remote = repo.remotes['origin'] if repo
      # Includes git.kde.org, otherwise it would run on *.neon.kde.org.
      # also, don't include scratch and clones, they don't have projects
      # associated with them.
      url = remote.url if remote&.url&.include?('invent.kde.org')
      return nil if url && remote&.url&.include?('/qt/') # qt fork has no l10n

      url || nil
    end

    def inject_l10n!(source_path)
      # This is ./source, while path is ./build/source
      url = repo_url_from_path('source')
      l10n_log.info "l10n injection for url #{url}."
      return unless url

      # TODO: this would benefit from classing
      add_l10n(source_path, url)
    end
  end

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
