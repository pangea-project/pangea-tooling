# frozen_string_literal: true

# SPDX-FileCopyrightText: 2014-2021 Harald Sitter <sitter@kde.org>
# SPDX-License-Identifier: LGPL-2.1-only OR LGPL-3.0-only OR LicenseRef-KDE-Accepted-LGPL

require_relative 'apt'
require_relative 'aptly-ext/filter'
require_relative 'aptly-ext/package'
require_relative 'debian/changes'
require_relative 'dpkg'
require_relative 'lsb'
require_relative 'nci'
require_relative 'os'
require_relative 'retry'

require 'concurrent'
require 'date'
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
    @install_exclusion = %w[base-files libblkid1 libblkid-dev]
    # Qt5 and 6 appstream-dev conflict each other. Deal with this at a later point in time when the dust has settled a bit
    @install_exclusion << 'libappstreamqt-dev' if (DateTime.new(2023, 12, 1) - DateTime.now) > 0.0
    # software-properties backs up Apt::Repository, must not be removed.
    @purge_exclusion = %w[base-files python3-software-properties
                          apt libapt-pkg5.0 libblkid1 libblkid-dev
                          neon-settings neon-settings-2 libseccomp2 neon-adwaita libdrm2 libdrm-dev libdrm-common
                          libdrm-test libdrm2-udeb libdrm-intel libdrm-radeon1 libdrm-common libdrm-intel1
                          libdrm-amdgpu1 libdrm-tests libdrm-nouveau2]

    p self
  end

  def add
    repo = Apt::Repository.new(@_name)
    return true if repo.add && update_with_retry

    remove
    false
  end

  def remove
    repo = Apt::Repository.new(@_name)
    return true if repo.remove && update_with_retry

    false
  end

  def install
    @log.info "Installing PPA #{@_name}."
    return false if packages.empty?

    pin!
    args = %w[ubuntu-minimal]
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

    Apt.purge(packages.keys.delete_if { |x| purge_excluded?(x) }, args: %w[--allow-remove-essential])
  end

  private

  def update_with_retry
    # Aptly doesn't do by-hash repos so updates can have hash mismatches.
    # Also general network IO problems...
    # Maybe Apt.update should just retry itself?
    Retry.retry_it(times: 4, sleep: 4) { Apt.update || raise }
  end

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
    # TODO: REVERT: This should not be needed at all, but I can't get tests
    # working where it automatically fetches prefix from the aptly.
    # I'll revert this when I get tests working but for now to get lint
    # working this is crude solution
    if NCI.divert_repo?(prefix)
      super("http://archive.neon.kde.org/tmp/#{prefix}")
    else
      super("http://archive.neon.kde.org/#{prefix}")
    end
  end

  # FIXME: Why is this public?!
  def sources
    @sources ||= begin
      sources = @repo.packages(q: '$Architecture (source)')
      Aptly::Ext::LatestVersionFilter.filter(sources)
    end
  end

  private

  def new_query_pool
    # Run on a tiny thread pool so we don't murder the server with queries
    # Use a very lofty queue to avoid running into scheduling problems when
    # the connection is very slow.
    Concurrent::ThreadPoolExecutor.new(min_threads: 2, max_threads: 4,
                                       max_queue: sources.size * 2)
  end

  # Helper to build aptly queries.
  # This is more of an exercise in design of how a proper future builder might
  # look and feel.
  # TODO: could move to aptly ext and maybe aptly-api itself, may benefit from
  #   some more engineering to allow building queries as a form of DSL?
  class QueryBuilder
    attr_reader :query

    def initialize
      @query = nil
    end

    def and(suffix, **kwords)
      suffix = format(suffix, kwords) unless kwords.empty?
      unless query
        @query = suffix
        return self
      end
      @query += ", #{suffix}"
      self
    end

    def to_s
      @query
    end
  end

  def query_str_from_source(source)
    QueryBuilder.new
                .and('!$Architecture (source)')
                .and('$PackageType (deb)') # we particularly dislike udeb!
                .and('$Source (%<name>s)', name: source.name)
                .and('$SourceVersion (%<version>s)', version: source.version)
                .to_s
  end

  def query_packages_from_sources
    puts 'Querying packages from aptly.'
    pool = new_query_pool
    promises = sources.collect do |source|
      q = query_str_from_source(source)
      Concurrent::Promise.execute(executor: pool) do
        Retry.retry_it(times: 4, sleep: 4) { @repo.packages(q: q) }
      end
    end
    Concurrent::Promise.zip(*promises).value!.flatten
  end

  def packages
    @packages ||= begin
      packages = query_packages_from_sources
      packages = Aptly::Ext::LatestVersionFilter.filter(packages)
      arch_filter = [DPKG::HOST_ARCH, 'all']
      packages.select! { |x| arch_filter.include?(x.architecture) }
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

  def cleanup_pid(pid)
    Process.kill('KILL', pid)
    Process.wait(pid)
  rescue Errno::ECHILD
    puts "pid #{pid} already dead apparently. got ECHILD"
  end

  def dbus_run_custom(&_block)
    system_pid = dbus_daemon
    session_env = dbus_session
    session_pid = session_env.fetch('DBUS_SESSION_BUS_PID').to_i
    ENV.update(session_env)
    yield
  ensure
    # Kill, this is a single-run sorta thing inside the container.
    cleanup_pid(session_pid) if session_pid
    cleanup_pid(system_pid) if system_pid
  end

  def dbus_run(&block)
    if ENV.key?('DBUS_SESSION_BUS_ADDRESS')
      yield
    else
      dbus_run_custom(&block)
    end
  end

  def internal_setup_gir
    Apt.install('packagekit', 'libgirepository1.0-dev', 'gir1.2-packagekitglib-1.0', 'dbus-x11') || raise
    require_relative 'gir_ffi'
    true
  end

  def setup_gir
    @setup ||= internal_setup_gir
    @gir ||= GirFFI.setup(:PackageKitGlib, '1.0')
  end

  # @returns <GLib::PtrArray> of {PackageKitGlib.Package} instances
  def packagekit_packages
    dbus_run do
      client = PackageKitGlib::Client.new
      filter = PackageKitGlib::FilterEnum[:arch]
      return client.get_packages(filter).package_array.collect(&:name)
    end
  end

  def packages
    # Ditch version for this. Latest is good enough, we expect no wanted repos
    # to be enabled at this point anyway.
    @packages ||= begin
      Apt::Cache.disable_auto_update { mangle_packages }
    end
  end

  def mangle_packages
    setup_gir
    packages = []
    pk_packages = packagekit_packages # grab a list of all known names
    puts "Ubuntu packages: #{pk_packages}"
    # self is actually a meta version assembling multiple repos' packages
    @repos.each do |repo|
      repo_packages = repo.send(:packages).keys.dup
      repo_packages -= packages # substract already known packages.
      repo_packages.each { |k| packages << k if pk_packages.include?(k) }
    end
    packages
  end
end

# Special repository type which filters the sources based off of the
# changes file in PWD.
class ChangesSourceFilterAptlyRepository < ::AptlyRepository
  def sources
    @sources ||= begin
      changes = Debian::Changes.new(Dir.glob('*.changes')[0])
      changes.parse!
      # Aptly api is fairly daft and has no proper R/WLock right now, so
      # reads time out every once in a while, guard against this.
      # Exepctation is that the timeout is reasonably short so we don't wait
      # too long multiple times in a row.
      s = Retry.retry_it(times: 8, sleep: 4) do
        @repo.packages(q: format('%s (= %s) {source}',
                                 changes.fields['Source'],
                                 changes.fields['Version']))
      end
      s.collect { |x| Aptly::Ext::Package::Key.from_string(x) }
    end
  end

  # TODO: move to unified packages meth name
  def binaries
    packages
  end
end
