# frozen_string_literal: true
#
# Copyright (C) 2015-2016 Harald Sitter <sitter@kde.org>
# Copyright (C) 2015 Rohan Garg <rohan@kde.org>
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
require 'jenkins_junit_builder'
require 'tty/command'

require_relative 'dependency_resolver'
require_relative 'kcrash_link_validator'
require_relative 'setcap_validator'
require_relative 'source'
require_relative '../apt'
require_relative '../debian/control'
require_relative '../dpkg'
require_relative '../os'
require_relative '../retry'
require_relative '../debian/dsc'

module CI
  # Junit report about binary only resoluting being used.
  # This is a bit of a hack as we want
  class JUnitBinaryOnlyBuild
    def initialize
      @suite = JenkinsJunitBuilder::Suite.new
      @suite.package = 'PackageBuilder'
      @suite.name = 'DependencyResolver'

      c = JenkinsJunitBuilder::Case.new
      c.classname = 'DependencyResolver'
      c.name = 'binary_only'
      c.result = JenkinsJunitBuilder::Case::RESULT_FAILURE
      c.system_out.message = msg

      @suite.add_case(c)
    end

    def msg
      <<-ERRORMSG
This build failed to install the entire set of build dependencies a number of
times and fell back to only install architecture dependent dependencies. This
results in the build not having any architecture independent packages!
This is indicative of this source (and probably all associated sources)
requiring multiple rebuilds to get around a circular dependency between
architecture dependent and architecture independent features.
Notably Qt is affected by this. If you see this error make sure to *force* a
rebuild of *all* related sources (e.g. all of Qt) *after* all sources have built
*at least once*.
      ERRORMSG
    end

    def to_xml
      @suite.build_report
    end

    def write_file
      FileUtils.mkpath('reports')
      File.write('reports/build_binary_dependency_resolver.xml', to_xml)
    end
  end

  # Builds a binary package.
  class PackageBuilder
    BUILD_DIR  = 'build'
    RESULT_DIR = 'result'

    BIN_ONLY_WHITELIST = %w[qtbase qtxmlpatterns qtdeclarative qtwebkit
                            test-build-bin-only].freeze

    def initialize
      # Cripple stupid bin calls issued by the dpkg build tooling. In our
      # overlay we have scripts that alter the behavior of certain commands that
      # are being called in an undesirable manner (e.g. causing too much output)
      overlay_path = File.expand_path("#{__dir__}/../../../overlay-bin")
      unless File.exist?(overlay_path)
        raise "could not find overlay bins in #{overlay_path}"
      end
      ENV['PATH'] = "#{overlay_path}:#{ENV['PATH']}"
      cross_setup
    end

    def extract
      FileUtils.rm_rf(BUILD_DIR, verbose: true)
      return if system('dpkg-source', '-x', @dsc, BUILD_DIR)
      raise 'Something went terribly wrong with extracting the source'
    end

    def build_env
      deb_build_options = ENV.fetch('DEB_BUILD_OPTIONS', '').split(' ')
      {
        'DEB_BUILD_OPTIONS' => (deb_build_options + ['nocheck']).join(' '),
        'DH_BUILD_DDEBS' => '1',
        'DH_QUIET' => '1'
      }
    end

    def logged_system(env, *cmd)
      env_string = build_env.map { |k, v| "#{k}=#{v}" }.join(' ')
      cmd_string = cmd.join(' ')
      puts "Running: #{env_string} #{cmd_string}"
      system(env, *cmd)
    end

    def build_package
      # FIXME: buildpackage probably needs to be a method on the DPKG module
      #   for logging purposes and so on and so forth
      # Signing happens outside the container. So disable all signing.
      dpkg_buildopts = %w[-us -uc] + build_flags

      Dir.chdir(BUILD_DIR) do
        SetCapValidator.run do
          KCrashLinkValidator.run do
            unless logged_system(build_env, 'dpkg-buildpackage', *dpkg_buildopts)
              raise_build_failure
            end
          end
        end
      end
    end

    def print_contents
      Dir.chdir(RESULT_DIR) do
        debs = Dir.glob('*.deb')
        debs.each do |deb|
          cmd = TTY::Command.new(uuid: false, printer: :null)
          out, = cmd.run('lesspipe', deb)
          File.write("#{deb}.info.txt", out)
        end
      end
    end

    # dpkg-* cannot dumps artifact into a specific dir, so we need move
    # them about.
    # https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=657401
    def move_binaries
      Dir.mkdir(RESULT_DIR) unless Dir.exist?(RESULT_DIR)
      changes = Dir.glob("#{BUILD_DIR}/../*.changes")

      changes.reject! { |e| e.include?('source.changes') }

      unless changes.size == 1
        warn "Not exactly one changes file WTF -> #{changes}"
        return
      end

      system('dcmd', 'mv', '-v', *changes, 'result/')
    end

    def build
      dsc_glob = Dir.glob('*.dsc')
      raise "Not exactly one dsc! Found #{dsc_glob}" unless dsc_glob.count == 1
      @dsc = dsc_glob[0]

      unless (arch_all_source? && arch_all?) || matches_host_arch?
        puts 'INFO: Package architecture does not match host architecture'
        return
      end

      extract
      install_dependencies
      build_package
      move_binaries
      print_contents
    end

    private

    # Apt resolver is opt-in for now.
    RESOLVER = if ENV['PANGEA_APT_RESOLVER']
                 DependencyResolverAPT
               else
                 DependencyResolver
               end

    def raise_build_failure
      msg = 'Failed to build from source!'
      msg += ' This source was built in bin-only mode.' if @bin_only
      raise msg
    end

    def arch_bin_only?
      value = ENV.fetch('PANGEA_ARCH_BIN_ONLY', 'true')
      case value.downcase
      when 'true', 'on'
        return true
      when 'false', 'off'
        return false
      end
      raise "Unexpected value in PANGEA_ARCH_BIN_ONLY: #{value}"
    end

    # auto determine if bin_only is cool or not.
    # NB: this intentionally doesn't take bin_only_possible?
    #   into account as this should theoretically be ok to do. BUT only as long
    #   as sources correctly implement binary only support correctly. If not
    #   this can fail in a number of awkward ways. Should that happen
    #   bin_only_possible? needs to get used (or a thing like it, possibly
    #   with a blacklist instead of a whitelist). Automatic bin-only in theory
    #   affords us faster build times on ARM when a source supports bin-only.
    # @return new bin_only
    def auto_bin_only(bin_only)
      return bin_only if bin_only || !arch_bin_only?

      bin_only = !arch_all?
      if bin_only
        puts '!!! Running in automatic bin-only mode. Building binary only.' \
              ' (skipping Build-Depends-Indep)'
      end
      bin_only
    end

    # Create a dep resolver
    # @param bin_only whether to force binary-only resolution. This will
    def dep_resolve(dir, bin_only: false)
      # This wraps around a conditional arch argument.
      # We can't just expand {} as that'd mess up mocha in the tests, so pass
      # arch only if it actually is applicable. This is a bit hackish but beats
      # potentially having to update a lot of tests.
      # IOW we only set bin_only if it is true so the expecations for
      # pre-existing scenarios remain the same.

      bin_only = auto_bin_only(bin_only)
      @bin_only = bin_only # track, builder will make flag adjustments

      opts = {}
      opts[:bin_only] = bin_only if bin_only
      opts[:arch] = cross_arch if cross?
      return RESOLVER.resolve(dir, **opts) unless opts.empty?

      RESOLVER.resolve(dir)
    end

    def install_dependencies
      dep_resolve(BUILD_DIR)
    rescue RuntimeError => e
      raise e unless bin_only_possible?

      warn 'Failed to resolve all build-depends, trying binary only' \
           ' (skipping Build-Depends-Indep)'
      dep_resolve(BUILD_DIR, bin_only: true)
      JUnitBinaryOnlyBuild.new.write_file
    end

    # @return [Bool] whether to mangle the build for Qt
    def bin_only_possible?
      @bin_only_possible ||= begin
        control = Debian::Control.new(BUILD_DIR)
        control.parse!
        source_name = control.source.fetch('Build-Depends-Indep', '')
        false unless BIN_ONLY_WHITELIST.include?(source_name)
        control.source.key?('Build-Depends-Indep')
      end
    end

    # @return [Array<String>] of build flags (-b -j etc.)
    def build_flags
      dpkg_buildopts = []
      if arch_all?
        dpkg_buildopts += build_flags_arch_all
      else
        # Automatically decide how many concurrent build jobs we can support.
        dpkg_buildopts << '-jauto'
        # We only build arch:all on amd64, all other architectures must only
        # build architecture dependent packages. Otherwise we have confliciting
        # checksums when publishing arch:all packages of different architectures
        # to the repo.
        dpkg_buildopts << '-B'
      end
      dpkg_buildopts << '-a' << cross_arch if cross?
      # If we only installed @bin_only dependencies as indep didn't want to
      # install we'll coerce -b into -B irregardless of platform.
      dpkg_buildopts.collect! { |x| x == '-b' ? '-B' : x } if @bin_only
      dpkg_buildopts
    end

    def build_flags_arch_all
      flags = []
      # Automatically decide how many concurrent build jobs we can support.
      # Persistent amd64 nodes are used across all our CIs and they are super
      # weak in the knees - be nice!
      flags << '-j1'
      flags << '-jauto' if scaling_node? # entirely use cloud nodes
      # On arch:all only build the binaries, the source is already built.
      flags << '-b'
      flags
    end

    # FIXME: this is not used
    def build_flags_cross
      # Unclear if we need config_site CONFIG_SITE=/etc/dpkg-cross/cross-config.i386
      [] << '-a' << cross_arch
    end

    def cross?
      @is_cross ||= !cross_arch.nil?
    end

    def cross_arch
      @cross_arch ||= ENV['PANGEA_CROSS']
    end

    def cross_triplet
      { 'i386' => 'i686-linux-gnu' }.fetch(cross_arch)
    end

    def cross_setup
      return unless cross?
      cmd = TTY::Command.new(uuid: false)
      cmd.run('dpkg', '--add-architecture', cross_arch)
      Apt.update || raise
      Apt.install("gcc-#{cross_triplet}",
                  "g++-#{cross_triplet}",
                  'dpkg-cross') || raise
    end

    def host_arch
      return nil unless cross?

      cross_arch
    end

    def arch_all?
      DPKG::HOST_ARCH == 'amd64'
    end

    def arch_all_source?
      parsed_dsc = Debian::DSC.new(@dsc)
      parsed_dsc.parse!
      architectures = parsed_dsc.fields['architecture'].split
      return true if architectures.include?('all')
    end

    def matches_host_arch?
      parsed_dsc = Debian::DSC.new(@dsc)
      parsed_dsc.parse!
      architectures = parsed_dsc.fields['architecture'].split
      architectures.any? do |arch|
        DPKG::Architecture.new(host_arch: host_arch).is(arch)
      end
    end

    def scaling_node?
      File.exist?('/tooling/is_scaling_node')
    end
  end
end
