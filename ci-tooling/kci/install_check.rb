#!/usr/bin/env ruby

require 'fileutils'
require 'logger'
require 'logger/colors'
require 'open3'
require 'tmpdir'

require_relative 'lib/apt'
require_relative 'lib/aptly-ext/filter'
require_relative 'lib/dpkg'
require_relative 'lib/lp'
require_relative 'lib/retry'
require_relative 'lib/thread_pool'

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
    @log.info "Installing PPA #{@type}."
    return false if packages.empty?
    pin!
    args = %w(ubuntu-minimal)
    args += packages.map { |k, v| "#{k}=#{v}" }
    Apt.install(args)
  end

  def purge
    @log.info "Purging PPA #{@type}."
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

  def sources
    [] # not implemented, not sure why we needed this at all.
  end

  private

  def packages
    @packages ||= begin
      sources = @repo.packages(q: '$Architecture (source)')
      sources = Aptly::Ext::LatestVersionFilter.filter(sources)

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

class InstallCheckBase
  def initialize
    @log = Logger.new(STDOUT)
    @log.level = Logger::INFO
  end

  def run(candidate_ppa, target_ppa)
    candidate_ppa.remove # remove live before attempting to use daily.

    # Add the present daily snapshot, install everything.
    # If this fails then the current snapshot is kaputsies....
    if target_ppa.add
      unless target_ppa.install
        @log.info 'daily failed to install.'
        daily_purged = target_ppa.purge
        unless daily_purged
          @log.info 'daily failed to install and then failed to purge. Maybe check' \
                   ' maintscripts?'
        end
      end
    end
    @log.unknown 'done with daily'

    # NOTE: If daily failed to install, no matter if we can upgrade live it is
    # an improvement just as long as it can be installed...
    # So we purged daily again, and even if that fails we try to install live
    # to see what happens. If live is ok we are good, otherwise we would fail anyway

    candidate_ppa.add
    unless candidate_ppa.install
      @log.error 'all is vain! live PPA is not installing!'
      exit 1
    end

    # All is lovely. Let's make sure all live packages uninstall again
    # (maintscripts!) and then start the promotion.
    unless candidate_ppa.purge
      @log.error 'live PPA installed just fine, but can not be uninstalled again.' \
                ' Maybe check maintscripts?'
      exit 1
    end

    @log.info "writing package list in #{Dir.pwd}"
    File.write('sources-list.json', JSON.generate(candidate_ppa.sources))
  end
end

class InstallCheck < InstallCheckBase
  def install_fake_pkg(name)
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        Dir.mkdir(name)
        Dir.mkdir("#{name}/DEBIAN")
        File.write("#{name}/DEBIAN/control", <<-EOF.gsub(/^\s+/, ''))
        Package: #{name}
        Version: 999:999
        Architecture: all
        Maintainer: Harald Sitter <sitter@kde.org>
        Description: fake override package for kubuntu ci install checks
        EOF
        system("dpkg-deb -b #{name} #{name}.deb")
        DPKG.dpkg(['-i', "#{name}.deb"])
      end
    end
  end

  def run(candidate_ppa, target_ppa)
    if Process.uid == 0
      # Disable invoke-rc.d because it is crap and causes useless failure on install
      # when it fails to detect upstart/systemd running and tries to invoke a sysv
      # script that does not exist.
      File.write('/usr/sbin/invoke-rc.d', "#!/bin/sh\n")
      # Speed up dpkg
      File.write('/etc/dpkg/dpkg.cfg.d/02apt-speedup', "force-unsafe-io\n")
      # Prevent xapian from slowing down the test.
      # Install a fake package to prevent it from installing and doing anything.
      # This does render it non-functional but since we do not require the database
      # anyway this is the apparently only way we can make sure that it doesn't
      # create its stupid database. The CI hosts have really bad IO performance making
      # a full index take more than half an hour.
      install_fake_pkg('apt-xapian-index')
      File.open('/usr/sbin/update-apt-xapian-index', 'w', 0755) do |f|
        f.write("#!/bin/sh\n")
      end
      # Also install a fake resolvconf because docker is a piece of shit cunt
      # https://github.com/docker/docker/issues/1297
      install_fake_pkg('resolvconf')
      # Disable manpage database updates
      Open3.popen3('debconf-set-selections') do |stdin, _stdout, stderr, wait_thr|
        stdin.puts('man-db man-db/auto-update boolean false')
        stdin.close
        wait_thr.join
        puts stderr.read
      end
      # Make sure everything is up-to-date.
      abort 'failed to update' unless Apt.update
      abort 'failed to dist upgrade' unless Apt.dist_upgrade
      # Install ubuntu-minmal first to make sure foundations nonsense isn't going
      # to make the test fail half way through.
      abort 'failed to install minimal' unless Apt.install('ubuntu-minimal')
      # Because dependencies are fucked
      # [14:27] <sitter> dictionaries-common is a crap package
      # [14:27] <sitter> it suggests a wordlist but doesn't pre-depend them or
      # anything, intead it just craps out if a wordlist provider is installed but
      # there is no wordlist -.-
      system('apt-get install wamerican')
    end

    super
  end
end

if __FILE__ == $PROGRAM_NAME
  LOG = Logger.new(STDERR)
  LOG.level = Logger::INFO

  Project = Struct.new(:series, :stability)
  project = Project.new(ENV.fetch('DIST'), ENV.fetch('TYPE'))

  candiate_ppa = CiPPA.new("#{project.stability}-daily", project.series)
  target_ppa = CiPPA.new(project.stability.to_s, project.series)
  InstallCheck.new.run(candiate_ppa, target_ppa)
  exit 0
end
