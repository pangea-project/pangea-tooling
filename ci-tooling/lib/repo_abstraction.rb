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

require_relative 'aptly-ext/filter'
require_relative 'dpkg'
require_relative 'lsb'
require_relative 'lp'

# We can't really module this because it is used API. Ugh.

# FIXME: maybe this should be a module that gets prepended
# init options are questionable through
# with a prepend we can easily have global as well as repo specific package
# filters though as a hook-mechanic without having to explicitly do stupid
# hooks
class Repository
  def initialize(name)
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO

    # FIXME: daft, we should only have one repo and add/remove it
    #        can't do this currently because equality sequence with old code
    #        demands multiple repos
    @_name = name
    # @_repo = Apt::Repository.new(name)
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
    args += packages.map { |k, v| "#{k}=#{v}" }
    Apt.install(args)
  end

  def purge
    @log.info "Purging PPA #{@_name}."
    return false if packages.empty?
    Apt.purge(packages.keys.delete_if { |x| x.include?('base-files') })
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
      @repo.packages(q: '$Architecture (source)')
      Aptly::Ext::LatestVersionFilter.filter(sources)
    end
  end

  private

  def packages
    @packages ||= begin
      packages = sources.collect do |source|
        q = format('!$Architecture (source), $Source (%s), $SourceVersion (%s)',
                   source.name, source.version)
        @repo.packages(q: q)
      end.flatten
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
