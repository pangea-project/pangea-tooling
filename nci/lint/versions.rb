# frozen_string_literal: true
# SPDX-FileCopyrightText: 2017-2020 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require 'minitest/test'
require 'tty/command'
require 'httparty'

require_relative '../../ci-tooling/lib/apt'
require_relative '../../ci-tooling/lib/aptly-ext/filter'
require_relative '../../ci-tooling/lib/debian/version'
require_relative '../../ci-tooling/lib/dpkg'
require_relative '../../ci-tooling/lib/retry'
require_relative '../../ci-tooling/lib/nci'
require_relative '../../lib/aptly-ext/remote'

# rubocop:disable Style/BeginBlock
BEGIN {
  # Use 4 threads in minitest parallelism, apt-cache is heavy, so we can't
  # bind this to the actual CPU cores. 4 Is reasonably performant on SSDs.
  ENV['MT_CPU'] ||= '4'
}
# rubocop:enable

module NCI
  # Lists all architecture relevant packages from an aptly repo.
  class RepoPackageLister
    def self.default_repo
      "#{ENV.fetch('TYPE')}_#{ENV.fetch('DIST')}"
    end

    def self.current_repo
      "#{ENV.fetch('TYPE')}_#{NCI.current_series}"
    end

    def self.old_repo
      if NCI.future_series
        "#{ENV.fetch('TYPE')}_#{NCI.current_series}" # "old" is the current one
      elsif NCI.old_series
        "#{ENV.fetch('TYPE')}_#{NCI.old_series}"
      else
        raise "Don't know what old or future is, maybe this job isn't" \
              " necessary and should be deleted?"
      end
    end

    def initialize(repo = Aptly::Repository.get(self.class.default_repo))
      @repo = repo
    end

    def packages
      @packages ||= begin
        packages = Retry.retry_it(times: 4, sleep: 4) do
          @repo.packages(q: '!$Architecture (source)')
        end
        packages = Aptly::Ext::LatestVersionFilter.filter(packages)
        arch_filter = [DPKG::HOST_ARCH, 'all']
        packages.select { |x| arch_filter.include?(x.architecture) }
      end
    end
  end

  # Lists packages in a directory by dpkg-deb inspecting all *.deb
  # files.
  class DirPackageLister
    Package = Struct.new(:name, :version)

    def initialize(dir)
      @dir = File.expand_path(dir)
    end

    def packages
      @packages ||= begin
        cmd = TTY::Command.new(printer: :null)
        Dir.glob("#{@dir}/*.deb").collect do |debfile|
          out, _err = cmd.run('dpkg-deb',
                              "--showformat=${Package}\t${Version}\n",
                              '--show', debfile)
          out.split($/).collect { |line| Package.new(*line.split("\t")) }
        end.flatten
      end
    end
  end

  # Helper class for VersionsTest.
  # Implements the logic for a package version check. Takes a pkg
  # as input and then checks that the input's version is higher than
  # whatever is presently available in the apt cache (i.e. ubuntu or
  # the target neon repos).
  class PackageVersionCheck
    class VersionNotGreaterError < StandardError; end

    attr_reader :pkg

    def initialize(pkg)
      @pkg = pkg
      @cmd = TTY::Command.new(printer: :null)
    end

    def our_version
      Debian::Version.new(pkg.version)
    end

    def self.cmd
      @cmd ||= TTY::Command.new(printer: :null)
    end

    def self.cmd=(cmd)
      @cmd = cmd
    end

    # returns a hash of name=>version. version may be nil!
    def self.load_theirs(packages)
      names = packages.collect(&:name)
      # The overhead of apt is rather substantial, so we'll want to get all
      # data in one go ideally. Should this exhaust some argument limit
      # at some point we'll want to split into chunks instead.
      res = cmd.run('apt-cache', 'policy', *names)

      map = {}
      name = nil
      version = nil
      res.out.split("\n").each do |line|
        if line.start_with?(/^\w.+:/) # package lines aren't indented
          name = line.split(':', 2)[0].strip
          next
        end
        if line.start_with?(/\s+Candidate:/) # always indented
          version = line.split(':', 2)[1].strip
          raise line unless name && !name.empty?
          raise line unless version && !version.empty?
          version = version == '(none)' ? nil : Debian::Version.new(version)
          map[name.strip] = version
          name = nil
          version = nil
          next
        end
      end

      @their_versions = map
    end

    def self.their_versions
      raise "load_theirs wasn't called" unless @their_versions
      @their_versions
    end

    def their_version
      self.class.their_versions.fetch(pkg.name, nil)
    end

    def result_is_probably_virtual?(res)
      # When called from a terminal apt tells us this is a pure virtual, but
      # when called through a script it just doesn't say anything except for
      # the stupid warning about CLI interface being unstable.
      # Infer from an empty output and only the warning on stderr that the
      # package is virtual. This sucks balls.
      out = res.out.strip
      err = res.err.strip
      out.empty? &&
        err.split($/).size == 1 &&
        err.include?('does not have a stable CLI interface')
    end

    def run
      theirs = their_version
      ours = our_version
      return unless theirs # failed to find the package, we win.
      return if ours > theirs
      raise VersionNotGreaterError, <<~ERRORMSG
        Our version of
        #{pkg.name} #{ours} < #{theirs}
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
  end

  class PackageUpgradeVersionCheck < PackageVersionCheck

    # Download and parse the neon-settings xenial->bionic pin override file
    def self.override_packages
      @@override_packages ||= begin
        url = "https://packaging.neon.kde.org/neon/settings.git/plain/etc/apt/preferences.d/99-xenial-overrides?h=Neon/release-lts"
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

    def self.future_packages
      @@future_packages ||= begin
        @repo = Aptly::Repository.get("#{ENV.fetch('TYPE')}_#{ENV.fetch('DIST')}")
        future_packages = Retry.retry_it(times: 4, sleep: 4) do
          @repo.packages(q: '!$Architecture (source)')
        end
        future_packages = Aptly::Ext::LatestVersionFilter.filter(future_packages)
        arch_filter = [DPKG::HOST_ARCH, 'all']
        future_packages.select { |x| arch_filter.include?(x.architecture) }
        future_packages
      end
    end

    def run
      return if pkg.name.include? 'dbg'
      # set theirs to ubuntu bionic from container apt show, do not report if no package in ubuntu bionic
      theirs = their_version || return # Debian::Version.new('0')
      # get future neon (bionic) aptly version, set theirs if larger
      PackageUpgradeVersionCheck.future_packages
      neon_future_packages = @@future_packages.select { |x| x.name == "#{pkg.name}" }
      if neon_future_packages.length > 0
        future_version = Debian::Version.new(neon_future_packages[0].version)
        theirs = future_version if future_version > theirs
      end

      ours = our_version # neon xenial from aptly
      return unless theirs # failed to find the package, we win.
      return if ours < theirs
      PackageUpgradeVersionCheck.override_packages
      return if @@override_packages.include?(pkg.name) # already pinned in neon-settings
      raise VersionNotGreaterError, <<~ERRORMSG
        Current series version of
        #{pkg.name} #{ours} is greater than future series version #{theirs}
        which is currently available in apt (likely from Ubuntu or us).
      ERRORMSG
    end
  end

  # Very special test type.
  #
  # When in a pangea testing scope this test while aggregate will not
  # report any test methods (even if there are), this is to avoid problems
  # if/when we use minitest for pangea testing at large
  #
  # The purpose of this class is to easily get jenkins-converted data
  # out of a "test". Test in this case not being a unit test of the tooling
  # but a test of the package versions in our repo vs. on the machine we
  # are on (i.e. repo vs. ubuntu or other repo).
  # Before doing anything this class needs a lister set. A lister
  # implements a `packages` method which returns an array of objects with
  # `name` and `version` attributes describing the packages we have.
  # It then constructs concurrent promises checking if these packages'
  # versions are greater than the ones we have presently available in
  # the system.
  class VersionsTest < MiniTest::Test
    parallelize_me!

    class << self
      # :nocov:
      def runnable_methods
        return if ENV['PANGEA_UNDER_TEST']
        super
      end
      # :nocov:

      def reset!
        @lister = nil
        @promises = nil
      end

      def lister=(lister)
        raise 'lister mustnt be set twice' if @lister
        @lister = lister
        define_tests
      end
      attr_reader :lister

      # This is a tad meh. We basically need to meta program our test
      # methods as we'll want individual meths for each check so we get
      # this easy to read in jenkins, but since we only know which lister
      # to use once the program runs we'll have to extend ourselves lazily
      # via class_eval which allows us to edit the class from within
      # a class method.
      # The ultimate result is a bunch of test_pkg_version methods
      # which wait and potentially raise from their promises.
      def define_tests
        Apt.update if Process.uid.zero? # update if root
        packages = @lister.packages
        PackageVersionCheck.load_theirs(packages)
        packages.each do |pkg|
          class_eval do
            define_method("test_#{pkg.name}_#{pkg.version}") do
              PackageVersionCheck.new(pkg).run
            end
          end
        end
      end
    end

    def initialize(name = self.class.to_s)
      # Override and provide a default param for name so our tests can
      # pass without too much internal knowledge.
      super
    end
  end

  class UpgradeVersionsTest < VersionsTest
    class << self
      def define_tests
        Apt.update if Process.uid.zero? # update if root
        packages = @lister.packages
        PackageUpgradeVersionCheck.load_theirs(packages)
        packages.each do |pkg|
          class_eval do
            define_method("test_#{pkg.name}_#{pkg.version}") do
              PackageUpgradeVersionCheck.new(pkg).run
            end
          end
        end
      end
    end
  end

end
