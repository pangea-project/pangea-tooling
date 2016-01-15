require 'fileutils'

require_relative '../debian/changelog'
require_relative '../lsb'
require_relative 'build_version'
require_relative 'source'
require_relative 'tar_fetcher'

module CI
  class OrigSourceBuilder
    extend Gem::Deprecate

    def initialize(release: LSB::DISTRIB_CODENAME)
      # @name
      # @version
      # @tar
      @release = release

      # FIXME: hardcoded
      @build_rev = 1
      # FIXME: hardcoded
      @flavor = 'kubuntu'

      @packagingdir = File.absolute_path('packaging')

      # This is probably behavior that should be in a base sourcer?
      FileUtils.rm_r('build') if Dir.exist?('build')
      Dir.mkdir('build')
      @builddir = File.absolute_path('build')

      @sourcepath = "#{@builddir}/source" # Created by extract.

      # FIXME: builder should generate a Source instance
    end

    # FIXME: why would the builder need to know how to get the source?
    def retrieve_tar
      fetcher = WatchTarFetcher.new("#{@packagingdir}/debian/watch")
      fetcher.fetch(@builddir)
    end
    deprecate :retrieve_tar, WatchTarFetcher, 2015, 11
    alias_method :get_tar, :retrieve_tar

    # FIXME: this needs to happen magically somehow?
    def sourcepath
      return @sourcedir if @sourcedir
      Dir.chdir('build') do
        tar = Dir.glob('*.tar.*')
        abort unless tar.size != 1 || tar.zie != 2
        tar = tar[0]
        abort unless system('tar', '-xf', tar)
        # FIXME: this should possibly simply extract to a subdir and make sure
        #        that the everything is in ONE subdir or else move it in one.
        #        the present code wouldn't handle tars with multiple files
        #        rather than a dir.
        dirs = Dir.glob('*').reject { |d| !File.directory?(d) }
        abort unless dirs.size == 1
        @sourcedir = File.absolute_path(dirs[0])
      end
      @sourcedir
    end
    deprecate :sourcepath, "#{Tarball}.extract", 2015, 11

    def log_change
      # FIXME: this has email and fullname from env, see build_source
      # FIXME: code copy from build_source
      changelog = Changelog.new
      fail "Can't parse changelog!" if changelog.nil?
      base_version = changelog.version
      if base_version.include?('ubuntu')
        base_version = base_version.split('ubuntu')
        base_version = base_version[0..-2].join('ubuntu')
      end
      base_version = "#{base_version}#{@flavor}#{@build_rev}"
      # FIXME: code copy from build_source
      # FIXME: dch should include build url
      dch = %w(dch)
      dch << '--force-bad-version'
      dch << '--distribution' << @release
      dch << '-v' << base_version
      dch << 'Automatic CI Build'
      unless system(*dch)
        # :nocov:
        # dch cannot actually fail because we parse the changelog beforehand
        # so it is of acceptable format here already.
        fail 'Failed to create changelog entry'
        # :nocov:
      end
    end

    def build(tarball)
      FileUtils.cp(tarball.path, @builddir)
      tarball.extract(@sourcepath)
      FileUtils.cp_r(Dir.glob("#{@packagingdir}/*"), @sourcepath)
      Dir.chdir(@sourcepath) do
        log_change
        build_internal
      end
    end

    def build_internal
      # FIXME: code copy from build_source
      # dpkg-buildpackage
      Dir.chdir(@sourcepath) do
        system('update-maintainer')
        # Force -sa as reprepreo refuses to accept uploads without orig.
        return if system('dpkg-buildpackage', '-us', '-uc', '-S', '-d', '-sa')
        fail 'Could not run dpkg-buildpackage!'
      end
    end
  end
end
