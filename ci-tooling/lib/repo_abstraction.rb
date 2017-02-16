# frozen_string_literal: true
#
# Copyright (C) 2014-2016 Harald Sitter <sitter@kde.org>
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

require_relative 'apt'
require_relative 'aptly-ext/filter'
require_relative 'dpkg'
require_relative 'lsb'
require_relative 'lp'

require 'concurrent'
require 'gir_ffi'
require 'logger'
require 'shellwords'

# We can't really module this because it is used API. Ugh.

# FIXME: maybe this should be a module that gets prepended
# init options are questionable through
# with a prepend we can easily have global as well as repo specific package
# filters though as a hook-mechanic without having to explicitly do stupid
# hooks
class Repository
  attr_accessor :purge_exclusion

  def initialize(name)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

    # FIXME: daft, we should only have one repo and add/remove it
    #        can't do this currently because equality sequence with old code
    #        demands multiple repos
    @_name = name
    # @_repo = Apt::Repository.new(name)
    @install_exclusion = %w(base-files)
    # software-properties backs up Apt::Repository, must not be removed.
    @purge_exclusion = %w(base-files python3-software-properties
                          software-properties-common)
  end

  def add
    repo = Apt::Repository.new(@_name)
    return true if repo.add && Apt.update
    remove
    false
  end

  def remove
    repo = Apt::Repository.new(@_name)
    return true if repo.remove && Apt.update
    false
  end

  def install
    @log.info "Installing PPA #{@_name}."
    return false if packages.empty?
    pin!
    args = %w(ubuntu-minimal)
    # Map into install expressions, value can be nil so compact and join
    # to either get "key=value" or "key" depending on whether or not value
    # was nil.
    args += packages.map do |k, v|
      next '' if install_excluded?(k)
      [k, v].compact.join('=')
    end
    Apt.install(args)
  end

  def purge
    @log.info "Purging PPA #{@_name}."
    return false if packages.empty?
    Apt.purge(packages.keys.delete_if { |x| purge_excluded?(x) })
  end

  private

  def purge_excluded?(package)
    @purge_exclusion.any? { |x| x == package }
  end

  def install_excluded?(package)
    @install_exclusion.any? { |x| x == package }
  end
end

# An aptly repo for install testing
class AptlyRepository < Repository
  def initialize(repo, prefix)
    @repo = repo
    # FIXME: snapshot has no published_in
    # raise unless @repo.published_in.any? { |x| x.Prefix == prefix }
    super("http://archive.neon.kde.org/#{prefix}")
  end

  # FIXME: Why is this public?!
  def sources
    @sources ||= begin
      sources = @repo.packages(q: '$Architecture (source)')
      Aptly::Ext::LatestVersionFilter.filter(sources)
    end
  end

  private

  def query_packages_from_sources
    # Run on a tiny thread pool so we don't murder the server with queries
    # Use a very lofty queue to avoid running into scheduling problems when
    # the connection is very slow.
    pool = Concurrent::ThreadPoolExecutor.new(min_threads: 4, max_threads: 4,
                                              max_queue: sources.size * 2)
    promises = sources.collect do |source|
      q = format('!$Architecture (source), $Source (%s), $SourceVersion (%s)',
                 source.name, source.version)
      Concurrent::Promise.execute(executor: pool) { @repo.packages(q: q) }
    end
    Concurrent::Promise.zip(*promises).value.flatten
  end

  def packages
    @packages ||= begin
      packages = query_packages_from_sources
      p packages
      packages = Aptly::Ext::LatestVersionFilter.filter(packages)
      arch_filter = [DPKG::HOST_ARCH, 'all']
      packages.reject! { |x| !arch_filter.include?(x.architecture) }
      packages.reject! { |x| x.name.end_with?('-dbg', '-dbgsym') }
      packages.reject! { |x| x.name.start_with?('oem-config') }
      packages.map { |x| [x.name, x.version] }.to_h
    end
  end

  def pin!
    # FIXME: not implemented.
  end
end

# This is an addon that sits on top of one or more Aptly repos and basically
# replicates repo #add and #purge from Ubuntu repos but with the package list
# from an AptlyRepository.
# Useful to install the existing package set from Ubuntu and then upgrade on top
# of that.
class RootOnAptlyRepository < Repository
  def initialize(repos = [])
    super('ubuntu-fake-yolo-kitten')
    @repos = repos

    Apt.install('packagekit', 'libgirepository1.0-dev',
                'gir1.2-packagekitglib-1.0', 'dbus-x11') || raise
  end

  def add
    true # noop
  end

  def remove
    true # noop
  end

  def pin!
    # We don't need a pin for this use case as latest is always best.
  end

  private

  def dbus_daemon
    Dir.mkdir('/var/run/dbus')
    spawn('dbus-daemon', '--nofork', '--system', pgroup: Process.pid)
  end

  # Uses dbus-launch to start a session bus
  # @return Hash suitable for ENV exporting. Includes vars from dbus-launch.
  def dbus_session
    lines = `dbus-launch --sh-syntax`
    raise unless $?.success?
    lines = lines.strip.split($/)
    env = lines.collect do |line|
      next unless line.include?('=')
      data = line.split('=', 2)
      data[1] = Shellwords.split(data[1]).join.chomp(';')
      data
    end
    env.compact.to_h
  end

  def dbus_run(&_block)
    system_pid = dbus_daemon
    session_env = dbus_session
    session_pid = session_env.fetch('DBUS_SESSION_BUS_PID')
    ENV.update(session_env)
    yield
  ensure
    # Kill, this is a single-run sorta thing inside the container.
    Process.kill('KILL', session_pid)
    Process.wait(session_pid)
    Process.kill('KILL', system_pid)
    Process.wait(system_pid)
  end

  def setup_gir
    @gir ||= GirFFI.setup(:PackageKitGlib, '1.0')
  end

  # @returns <GLib::PtrArray> of {PackageKitGlib.Package} instances
  def packagekit_packages
    dbus_run do
      client = PackageKitGlib::Client.new
      filter = PackageKitGlib::FilterEnum[:arch] |
               PackageKitGlib::FilterEnum[:not_source] |
               PackageKitGlib::FilterEnum[:basename]
      return client.get_packages(filter).package_array
    end
  end

  def packages
    # Ditch version for this. Latest is good enough, we expect no wanted repos
    # to be enabled at this point anyway.
    @packages ||= begin
      Apt::Cache.disable_auto_update { mangle_packages }
    end
  end

  def mangle_packages(packages = {})
    # This pool actually runs risk of running out of queue space :|
    # When this happens we'll simply fallback to the let the caller run the
    # block. i.e. the main thread will run the future right now rather than
    # defering it.
    pool = Concurrent::ThreadPoolExecutor.new(min_threads: 2, max_threads: 8,
                                              fallback_policy: :caller_runs)
    setup_gir
    mangle_packages_with_futures(packages, executor: pool).each do |future|
      future.wait # Simply wait for each future in sequence. We need all.
      packages.delete(future.value![0]) unless future.value![1]
    end
    packages
  end

  def mangle_packages_with_futures(packages, futures = [],
                                   pk_packages = packagekit_packages,
                                   executor:)
    @repos.each do |repo|
      repo.send(:packages).each do |k, _|
        # If the package is known. Add it to our package set, otherwise drop
        # it entirely. This is necessary so we can expect apt to actually
        # return success and install the relevant packages.
        next if packages.key?(k)
        packages[k] = nil
        futures << Concurrent::Future.execute(executor: executor) do
          [k, pk_packages.any? { |x| x.name == k }]
        end
      end
    end
    futures
  end
end

# Helper to add/remove/list PPAs
class CiPPA < Repository
  attr_reader :type
  attr_reader :series

  def initialize(type, series)
    @type = type
    @series = series
    super("ppa:kubuntu-ci/#{@type}")
  end

  def sources
    return @sources if @sources

    @log.info "Getting sources list for PPA #{@type}."

    @sources = {}
    ppa_sources.each do |s|
      @sources[s.source_package_name] = s.source_package_version
    end
    @sources
  end

  private

  def packages
    return @packages if @packages

    @log.info "Building package list for PPA #{@type}."

    series = Launchpad::Rubber.from_path("ubuntu/#{@series}")
    host_arch = Launchpad::Rubber.from_url("#{series.self_link}/" \
                                           "#{DPKG::HOST_ARCH}")

    packages = {}

    source_queue = Queue.new
    ppa_sources.each { |s| source_queue << s }
    binary_queue = Queue.new
    BlockingThreadPool.run(8) do
      until source_queue.empty?
        source = source_queue.pop(true)
        Retry.retry_it do
          binary_queue << source.getPublishedBinaries
        end
      end
    end

    until binary_queue.empty?
      binaries = binary_queue.pop(true)
      binaries.each do |binary|
        if @log.debug?
          @log.debug format('%s | %s | %s',
                            binary.binary_package_name,
                            binary.architecture_specific,
                            binary.distro_arch_series_link)
        end
        # Do not include debug packages, they can't conflict anyway, and if
        # they did we still wouldn't care.
        next if binary.binary_package_name.end_with?('-dbg')
        # Do not include known to conflict packages
        next if binary.binary_package_name == 'libqca2-dev'
        # Do not include udebs, this unfortunately cannot be determined
        # easily via the API.
        next if binary.binary_package_name.start_with?('oem-config')
        # Backport, don't care about it being promoted.
        next if binary.binary_package_name.include?('ubiquity')
        next if binary.binary_package_name == 'kubuntu-ci-live'
        next if binary.binary_package_name == 'kubuntu-plasma5-desktop'
        if binary.architecture_specific
          unless binary.distro_arch_series_link == host_arch.self_link
            @log.debug '  skipping unsuitable arch of bin'
            next
          end
        end
        packages[binary.binary_package_name] = binary.binary_package_version
      end
    end

    @log.debug "Built package list: #{packages.keys.join(', ')}"
    @packages = packages
  end

  def ppa_sources
    return @ppa_sources if @ppa_sources
    series = Launchpad::Rubber.from_path("ubuntu/#{@series}")
    ppa = Launchpad::Rubber.from_path("~kubuntu-ci/+archive/ubuntu/#{@type}")
    @ppa_sources = ppa.getPublishedSources(status: 'Published',
                                           distro_series: series)
  end

  def pin!
    File.open('/etc/apt/preferences.d/superpin', 'w') do |file|
      file << "Package: *\n"
      file << "Pin: release o=LP-PPA-kubuntu-ci-#{@type}\n"
      file << "Pin-Priority: 999\n"
    end
  end
end
