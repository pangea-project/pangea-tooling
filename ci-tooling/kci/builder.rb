#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'timeout'

require_relative '../lib/apt'
require_relative '../lib/ci/build_source'
require_relative '../lib/debian/dsc_arch_twiddle'
require_relative '../lib/kci'
require_relative '../lib/lint/control'
require_relative '../lib/lint/log'
require_relative '../lib/lint/merge_marker'
require_relative '../lib/lint/result'
require_relative '../lib/lint/series'
require_relative '../lib/lint/symbols'
require_relative '../lib/retry'

# rubocop:disable Style/BlockComments
=begin
-> build_source
   - copy upstream source
   - generate tarball
   - copy packaging source
   - fiddle
   - update changelog
   - dpkg-buildpackage -S
-> sign_source [elevated - possibly part of build_source]
   - debsign
-> build binary
   - upload_source
   - wait_for_launchpad
   - download_logs
-> check_logs
   - cmake
   - lintian
   - symbols
   - qml-checker
-> update_symbols
=end
# rubocop:enable Style/BlockComments

# The Kubuntu CI Builder class. So old. So naughty.
class KCIBuilder
  class CoverageError < RuntimeError; end

  DPUTCONF = '/var/lib/jenkins/tooling/dput.cf'.freeze
  KEYID = '6A0C5BF2'.freeze
  Project = Struct.new(:series, :stability, :name)

  class << self
    attr_writer :testing

    def testing
      @testing ||= false
    end
  end

  def self.build_and_publish(project, source)
    Dir.chdir('build') do
      # Upload likes to get stuck, so we do timeout control to prevent all of
      # builder from getting stuck.
      # We try to dput two times in a row giving it first 30 minutes and then
      # 15 minutes to complete. If it didn't manage to upload after that we
      # ignore the package and move on.
      `cp -rf /var/lib/jenkins/.ssh /root/`
      `chown -Rv root:root /root/.ssh`
      if `ssh-keygen -F ppa.launchpad.net`.strip.empty?
        `ssh-keyscan -H ppa.launchpad.net >> ~/.ssh/known_hosts`
      end
      dput_args = [
        '-d',
        '-c',
        DPUTCONF,
        @ppa,
        "#{source.name}_#{source.build_version.tar}*.changes"
      ]
      dput = "dput #{dput_args.join(' ')}"
      success = false
      4.times do |count|
        # Note: count starts at 0 ;)
        if timeout_spawn(dput, 60 * (30.0 / (count + 1)))
          success = true
          break
        end
        sleep(60) # Sleep for a minute
      end
      abort '\t\t !!!!!!!!!! dput failed two times !!!!!!!!!!' unless success
      Dir.chdir('..') do # main dir
        require_relative 'source_publisher'
        publisher = SourcePublisher.new(source.name,
                                        source.version,
                                        project.stability)
        abort 'PPA Build Failed' unless publisher.wait
        # Write upload data to file, we perhaps want to do something outside the
        # build container.
        data = { name: source.name,
                 version: source.version,
                 type: project.stability }
        File.write('source.json', JSON.generate(data))
      end
    end
  end

  def self.run
    ENV['GNUPGHOME'] = '/var/lib/jenkins/tooling/gnupg'

    $stdout = $stderr

    # get basename, distro series, unstable/stable
    components = ARGV.fetch(0).split('_')
    unless components.size == 3
      abort 'Did not get a valid project identifier via ARGV0'
    end
    project = Project.new(components.fetch(0),
                          components.fetch(1),
                          components.fetch(2))

    @ppa = "ppa:kubuntu-ci/#{project.stability}"

    # PWD
    abort 'Could not change dir to ARGV1' unless Dir.chdir(ARGV.fetch(1))
    @workspace_path = ARGV.fetch(1)

    # Workaround for docker not having suidmaps. We run as root in the docker
    # which will result in uid/gid of written things to be 0 rather than
    # whatever jenkins has. So instead we have a fake jenkins user in the docker
    # we can chmod to. This ultimately ensures that the owernship is using the
    # uid of the host jenkins (equal to docker jenkins) such that we don't end
    # up with stuff owned by others.
    at_exit do
      FileUtils.chown_R('jenkins', 'jenkins', @workspace_path, verbose: true)
    end unless testing

    Retry.retry_it(times: 5, sleep: 8) do
      raise 'Failed to add' unless Apt::Repository.add(@ppa)
    end
    Retry.retry_it(times: 5, sleep: 8) do
      raise 'Failed to apt update' unless Apt.update
    end
    Retry.retry_it(times: 5, sleep: 8) do
      raise 'Failed to install' unless Apt.install(%w(pkg-kde-tools))
    end
    source = CI::VcsSourceBuilder.new(release: project.series).run

    # Mangle dsc to not do ARM builds unless explicitly enabled.
    # With hundreds of distinct sources on CI, building all of them on three
    # architectures, of which one is not too commonly used, is extremly
    # excessive.
    # Instead, by default we only build on the common architectures with extra
    # architectures needing to be enabled explicitly.
    # To achieve this mangle the Architecture field in the control file.
    # If it contains an uncommon arch -> remove it -> if it is empty now, abort
    # If it contains any -> replace with !uncommon
    # This is a cheapster hack implementation to avoid having to implement write
    # support in Debian control.
    begin
      Debian::DSCArch.twiddle!('build/')
    rescue Debian::DSCArch::Error => e
      # NOTE: this can raise a number of errors and we want them all to be fatal
      #  to prevent unhandled dscs or completely empty architectures from
      #  getting uploaded.
      abort e
    end

    raise CoverageError, 'Testing disabled after arch twiddle' if testing

    # Sign
    Dir.chdir('build/') do
      changes = Dir.glob('*.changes')
      abort "Expected only one changes file #{changes}" if changes.size != 1
      unless system("debsign -k#{KEYID} #{changes[0]}")
        abort 'Failed to sign the source.'
      end
    end

    build_and_publish(project, source)

    unless File.exist?('logs/i386.log')
      puts 'found no logs'
      exit 0
    end

    # We need discrete arrays of both logs and architectures they represent
    # to make sure we process them in the correct order when updating symbols.
    logs = []
    architectures_with_log = []
    Dir.chdir('logs/') do
      # `gunzip *.log.gz`
      Dir.glob('*.log').each do |log|
        logs << "#{@workspace_path}/logs/#{log}"
        architectures_with_log << File.basename(log, '.log')
      end
    end

    # Get archindep created by PPA script.
    archindep = File.read('archindep').strip
    log_data = File.open("logs/#{archindep}.log").read

    updated_symbols = update_symbols(log_data, logs, architectures_with_log,
                                     project, source)

    results = []
    # Lint log.
    results += lint_logs(log_data, updated_symbols: updated_symbols)
    # Lint control file
    results << Lint::Control.new('packaging').lint
    results << Lint::Series.new('packaging').lint
    results << Lint::Symbols.new('packaging').lint
    results << Lint::MergeMarker.new('packaging').lint

    Lint::ResultLogger.new(results).log

    # TODO: this script currently does not impact the build results nor does it
    # create parsable output
    qmlsrcs = %w(
      bluez-qt
      breeeze
      kactivities
      kalgebra
      kanagram
      kate
      kbreakout
      kdeplasma-addons
      kdeclarative
      kinfocenter
      koko
      kscreen
      ktp-desktop-applets
      kwin
      libkdegames
      plasma-framework
      plasma-desktop
      plasma-mediacenter
      plasma-nm
      plasma-sdk
      plasma-volume-control
      print-manager
      purpose
      milou
      muon
    )
    if !Dir.glob('source/**/*.qml').empty? && qmlsrcs.include?(project.name)
      require_relative 'lib/qml_dependency_verifier'

      dep_verify = QMLDependencyVerifier.new
      dep_verify.add_ppa
      missing_modules = dep_verify.missing_modules
      missing_modules.each do |package, modules|
        puts_warning "#{package} has missing dependencies..."
        modules.uniq! { |mod| { mod.identifier => mod.version } }
        modules.each do |mod|
          puts_info "  #{mod} not found."
          puts_info '    looked for:'
          mod.import_paths.each do |path|
            puts_info "      - #{path}"
          end
        end
      end
    end
  end

  # Upload
  def self.timeout_spawn(cmd, timeout)
    pid = Process.spawn(cmd, pgroup: true)
    begin
      Timeout.timeout(timeout) do
        Process.waitpid(pid, 0)
        return $?.exitstatus.zero?
      end
    rescue Timeout::Error
      Process.kill(15, -Process.getpgid(pid))
      return false
    end
  end

  def self.puts_kci(type, str)
    Lint::ResultLogger.puts_kci(type, str)
  end

  def self.puts_error(str)
    puts_kci('E', str)
  end

  def self.puts_warning(str)
    puts_kci('W', str)
  end

  def self.puts_info(str)
    puts_kci('I', str)
  end

  # Local
  def self.git_config(*args, global: false)
    cmd = %w(git config)
    cmd << '--global' if global
    system(*cmd, *args)
  end

  # Global
  def self.ggit_config(*args)
    git_config(*args, global: true)
  end

  def self.symbol_patch(version, architectures, logs)
    system('pkgkde-symbolshelper', 'batchpatch',
           '-v', version,
           '-c', architectures.join(','),
           logs.join(' '))
  end

  def self.gensymbols_regex
    start = 'dpkg-gensymbols: warning:'
    %r{#{start} (.*)/symbols doesn't match completely debian/(.*).symbols}
  end

  def self.update_symbols(log_data, logs, architectures_with_log, project,
                          source)
    updated_symbols = false
    # FIXME: stability wtf
    if project.series == KCI.latest_series && log_data.match(gensymbols_regex)
      puts 'KCI::SYMBOLS'
      retraction_warn = 'warning: some symbols or patterns disappeared in ' \
                        'the symbols file'
      if log_data.include?(retraction_warn)
        puts_error('It would very much appear that symbols have been retracted')
      else
        match = log_data.match(%r{--- debian/(.*).symbols})
        if match && match.size > 1
          Dir.chdir('packaging') do
            ggit_config('user.email', 'kubuntu-ci@lists.launchpad.net')
            ggit_config('user.name', 'Kubuntu CI')
            git_config('core.sparsecheckout')
            remote_ref = "remotes/packaging/kubuntu_#{project.stability}"
            system("git checkout -f #{remote_ref}")
            system('git branch -a')
            system('git status')
            system('git reset --hard')
            captures = match.captures
            captures.each do |lib_package|
              symbol_patch(source.build_version.base,
                           architectures_with_log,
                           logs)
              updated_symbols = $?.zero?
              puts_info("Auto-updated symbols of #{lib_package}")
            end
            # Username et al apparently is somehow coming from .git or something
            # apparently
            system('git status')
            system('git --no-pager diff')
            system('git commit -a -m "Automatic symbol update"')
          end
        else
          puts_error('Failed to update symbols as the package name(s) could ' \
                     'not be parsed.')
        end
      end
    end
    updated_symbols
  end

  def self.lint_cmake(data)
    cmake = Lint::Log::CMake.new
    cmake.load_include_ignores('packaging/debian/meta/cmake-ignore')
    cmake.ignores << CI::IncludePattern.new('Qt5TextToSpeech')
    cmake.lint(data.clone)
  end

  def self.lint_lintian(data, updated_symbols)
    lintian = Lint::Log::Lintian.new
    if updated_symbols
      label = 'symbols-file-contains-current-version-with-debian-revision'
      lintian.ignores << CI::IncludePattern.new(label)
    end
    lintian.lint(data.clone)
  end

  def self.lint_list_missing(data)
    Lint::Log::ListMissing.new.lint(data.clone)
  end

  def self.lint_logs(log_data, updated_symbols:)
    results = []
    results << lint_cmake(log_data)
    results << lint_lintian(log_data, updated_symbols)
    results << lint_list_missing(log_data)
    results
  end
end

if __FILE__ == $PROGRAM_NAME
  File.open('/etc/apt/apt.conf.d/apt-cacher', 'w') do |file|
    file.puts('Acquire::http { Proxy "http://10.0.3.1:3142"; };')
  end

  build_depends = %w(
    xz-utils
    dpkg-dev
    ruby
    dput
    debhelper
    pkg-kde-tools
    devscripts
    python-launchpadlib
    ubuntu-dev-tools
    git
  )
  Apt.install(build_depends)

  KCIBuilder.run
end
