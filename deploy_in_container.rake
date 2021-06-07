# frozen_string_literal: true
#
# Copyright (C) 2015-2018 Harald Sitter <sitter@kde.org>
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

# All the methods we have are task helpers, so they are fairly spagetthi.
# Blocks are tasks, so they are even worse offenders.
# Overengineering this into objects is probably not a smart move so let's ignore
# this (for now anyway).
# rubocop:disable Metrics/BlockLength, Metrics/MethodLength

require 'etc'
require 'fileutils'
require 'mkmf'
require 'open-uri'
require 'tmpdir'

require_relative 'lib/ci/fake_package'
require_relative 'lib/rake/bundle'
require_relative 'lib/nci'

DIST = ENV.fetch('DIST')
# These will be installed in one-go before the actual deps are being installed.
# This should only include stuff which is needed to make the actual DEP
# installation work!
EARLY_DEPS = [
  'python-apt-common', # Remove this once python-apt gets a Stretch template
  'eatmydata' # We disable fsync from apt and dpkg.
].freeze
# Core is not here because it is required as a build-dep or anything but
# simply a runtime (or provision time) dep of the tooling.
CORE_RUNTIME_DEPS = %w[apt-transport-https software-properties-common].freeze
DEPS = %w[xz-utils dpkg-dev dput debhelper pkg-kde-tools devscripts
          ubuntu-dev-tools gnome-pkg-tools git dh-systemd
          zlib1g-dev sudo locales mercurial aptitude
          autotools-dev cdbs dh-autoreconf dh-linktree germinate gnupg2
          gobject-introspection sphinx-common po4a pep8 pyflakes ppp-dev dh-di
          libgirepository1.0-dev libglib2.0-dev bash-completion
          python3-setuptools python3-setuptools-scm python-setuptools python-setuptools-scm dkms
          mozilla-devscripts libffi-dev subversion libcurl4-gnutls-dev
          libhttp-parser-dev javahelper rsync man-db].freeze + CORE_RUNTIME_DEPS

def home
  '/var/lib/jenkins'
end

def tooling_path
  '/tooling-pending'
end

def final_path
  '/tooling'
end

# Trap common exit signals to make sure the ownership of the forwarded
# volume is correct once we are done.
# Otherwise it can happen that bundler left root owned artifacts behind
# and the folder becomes undeletable.
%w[EXIT HUP INT QUIT TERM].each do |signal|
  Signal.trap(signal) do
    # Resolve uid and gid. FileUtils can do that internally but to do so
    # it will require 'etc' which in ruby2.7+rubygems can cause ThreadError
    # getting thrown out of require since the signal thread isn't necessarily
    # equipped to do on-demand-requires.
    # Since we have etc required already we may as well resolve the ids directly
    # and thus bypass the internal lookup of FU.
    uid = Etc.getpwnam('jenkins') ? Etc.getpwnam('jenkins').uid : nil
    gid = Etc.getgrnam('jenkins') ? Etc.getgrnam('jenkins').gid : nil
    next unless uid && gid

    FileUtils.chown_R(uid, gid, tooling_path, verbose: true, force: true)
  end
end

def install_fake_pkg(name)
  FakePackage.new(name).install
end

def custom_version_id
  require_relative 'lib/dci'
  # FIXME disabled jriddell 2021-06-07 due to broken DCI
  #return unless DCI.series.keys.include?(DIST)

  file = '/etc/os-release'
  os_release = File.readlines(file)
  # Strip out any lines starting with VERSION_ID
  # so that we don't end up with an endless number of VERSION_ID entries
  os_release.reject! { |l| l.start_with?('VERSION_ID') }
  system('dpkg-divert', '--local', '--rename', '--add', file) || raise
  os_release << "VERSION_ID=\"#{DCI.series[DIST]}\"\n"
  File.write(file, os_release.join)
end

def cleanup_rubies
  # We can have two rubies at a time, the system ruby and our ruby. We'll do
  # general purpose cleanup on all possible paths but then rip apart the system
  # ruby if we have our own ruby installed. This way we do not have unused gems
  # in scenarios where we used the system ruby previously but now use a custom
  # one.

  #  Gem cache and doc. Neither shoud be needed at runtime.
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/{cache,doc}/*'),
                  verbose: true)
  FileUtils.rm_rf(Dir.glob('/usr/local/lib/ruby/gems/*/{cache,doc}/*'),
                  verbose: true)
  #  libgit2 cmake build tree
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/gems/rugged-*/vendor/*/build'),
                  verbose: true)
  FileUtils.rm_rf(Dir.glob('/usr/local/lib/ruby/gems/*/gems/rugged-*/vendor/*/build'),
                  verbose: true)
  #  Other compiled extension artifacts not used at runtime
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/gems/*/ext/*/*.{so,o}'),
                  verbose: true)
  FileUtils.rm_rf(Dir.glob('usr/local/lib/ruby/gems/*/gems/*/ext/*/*.{so,o}'),
                  verbose: true)

  return unless find_executable('ruby').include?('local')

  puts 'Mangling system ruby'
  # All gems in all versions.
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/*'), verbose: true)
end

def cleanup_bundle
  Dir.chdir(tooling_path) do
    # Clean up now unused gems. This prevents unused versions of a gem
    # lingering in the image blowing up its size.
    clean_args = ['clean']
    clean_args << '--verbose'
    clean_args << '--force' # Force system clean!
    bundle(*clean_args)
  end
end

def deployment_cleanup
  # Ultimate clean up
  #  Semi big logs
  File.write('/var/log/lastlog', '')
  File.write('/var/log/faillog', '')
  File.write('/var/log/dpkg.log', '')
  File.write('/var/log/apt/term.log', '')

  cleanup_bundle
  cleanup_rubies
end

def bundle_install
  bundle_args = ['install']
  bundle_args << "--jobs=#{[Etc.nprocessors / 2, 1].max}"
  bundle_args << '--local'
  bundle_args << '--no-cache'
  bundle_args << '--frozen'
  bundle_args << '--system'
  # FIXME: this breaks deployment on nodes, for now disable this
  # https://github.com/pangea-project/pangea-tooling/issues/17
  #bundle_args << '--without' << 'development' << 'test'
  bundle(*bundle_args)
rescue => e
  log_dir = "#{tooling_path}/#{ENV['DIST']}_#{ENV['TYPE']}"
  Dir.glob('/var/lib/gems/*/extensions/*/*/*/mkmf.log').each do |log|
    dest = "#{log_dir}/#{File.basename(File.dirname(log))}"
    FileUtils.mkdir_p(dest)
    FileUtils.cp(log, dest, verbose: true)
  end
  raise e
end

# openqa
task :deploy_openqa do
  # Only openqa on neon dists and if explicitly enabled.
  next unless NCI.series.key?(DIST) &&
              ENV.fetch('PANGEA_PROVISION_AUTOINST', '') == '1'

  Dir.mktmpdir do |tmpdir|
    system 'git clone --depth 1 ' \
       "https://github.com/apachelogger/kde-os-autoinst #{tmpdir}/"
    Dir.chdir('/opt') { sh "#{tmpdir}/bin/install.rb" }
  end
end

desc 'Disable ipv6 on gpg so it does not trip over docker sillyness'
task :fix_gpg do
  # https://rvm.io/rvm/security#ipv6-issues
  gpghome = "#{Dir.home}/.gnupg"
  dirmngrconf = "#{gpghome}/dirmngr.conf"
  FileUtils.mkpath(gpghome, verbose: true)
  File.write(dirmngrconf, "disable-ipv6\n")
end

desc 'Upgrade to newer ruby if required'
task :align_ruby do
  FileUtils.rm_rf('/tmp/kitchen') # Instead of messing with pulls, just clone.
  sh format('git clone --depth 1 %s %s',
            'https://github.com/pangea-project/pangea-kitchen.git',
            '/tmp/kitchen')
  Dir.chdir('/tmp/kitchen') do
    # ruby_build checks our version against the pangea version and if necessary
    # installs a ruby in /usr/local which is more suitable than what we have.
    # If this comes back !0 and we are meant to be aligned already this means
    # the previous alignment failed, abort when this happens.
    if !system('./ruby_build.sh') && ENV['ALIGN_RUBY_EXEC']
      raise 'It seems rake was re-executed after a ruby version alignment,' \
            ' but we still found and unsuitable ruby version being used!'
    end
  end
  case $?.exitstatus
  when 0 # installed version is fine, we are happy.
    FileUtils.rm_rf('/tmp/kitchen')
    next
  when 1 # a new version was installed, we'll re-exec ourself.
    sh 'gem install rake'
    sh 'gem install tty-command'
    ENV['ALIGN_RUBY_EXEC'] = 'true'
    # Reload ourself via new rake
    exec('rake', *ARGV)
  else # installer crashed or other unexpected error.
    raise 'Error while aligning ruby version through pangea-kitchen'
  end
end

def with_ubuntu_pin
  pin_file = '/etc/apt/preferences.d/ubuntu-pin'

  ## not needed right now. only useful when ubuntu rolls back an update and we are stuck with a broken version
  return yield
  ##

  # rubocop:disable Lint/UnreachableCode
  if NCI.series.key?(DIST) # is a neon thing
    File.write(pin_file, <<~PIN)
      Package: *
      Pin: release o=Ubuntu
      Pin-Priority: 1100
    PIN
  end

  yield
ensure
  FileUtils.rm_f(pin_file, verbose: true)
end
# rubocop:enable Lint/UnreachableCode

desc 'deploy inside the container'
task :deploy_in_container => %i[fix_gpg align_ruby deploy_openqa] do
  final_ci_tooling_compat_path = File.join(home, 'tooling')
  final_ci_tooling_compat_compat_path = File.join(home, 'ci-tooling')

  File.write("#{Dir.home}/.gemrc", <<-EOF)
install: --no-document
update: --no-document
EOF

  Dir.chdir(tooling_path) do
    begin
      Gem::Specification.find_by_name('bundler')
      # Force in case the found bundler was installed for a different version.
      # Otherwise rubygems will raise an error when attempting to overwrite the
      # bin.
      sh 'gem update --force bundler'
    rescue Gem::LoadError
      Gem.install('bundler')
    end

    require_relative 'lib/apt'
    require_relative 'lib/retry'

    Apt.install(*EARLY_DEPS) || raise

    if NCI.series.keys.include?(DIST)
      puts "DIST in NCI, adding key"
      # Pre-seed NCI keys to speed up all builds and prevent transient
      # problems with talking to the GPG servers.
      Retry.retry_it(times: 3, sleep: 8) do
        puts "trying to add #{NCI.archive_key}"
        raise 'Failed to import key' unless Apt::Key.add(NCI.archive_key)
      end
      system 'apt-key list'
    end

    with_ubuntu_pin do
      Retry.retry_it(times: 5, sleep: 8) do
        # NOTE: apt.rb automatically runs update the first time it is used.
        raise 'Dist upgrade failed' unless Apt.dist_upgrade

        # Install libssl1.0 for systems that have it
        Apt.install('libssl-dev') unless Apt.install('libssl1.0-dev')
        raise 'Apt install failed' unless Apt.install(*DEPS)
        raise 'Autoremove failed' unless Apt.autoremove(args: '--purge')
        raise 'Clean failed' unless Apt.clean
      end
    end

    # Add debug for checking what version is being used
    bundle(*%w[--version])
    bundle_install

    FileUtils.rm_rf(final_path)
    FileUtils.mkpath(final_path, verbose: true)
    FileUtils.cp_r('./.', final_path, verbose: true)
    [final_ci_tooling_compat_path,
     final_ci_tooling_compat_compat_path].each do |compat|
      if File.symlink?(compat)
        FileUtils.rm(compat, verbose: true)
      elsif File.exist?(compat)
        FileUtils.rm_r(compat, verbose: true)
      end
      # Make sure the parent exists, in case of /var/lib/jenkins on slaves
      # that is not the case for new builds.
      FileUtils.mkpath(File.dirname(compat))
      FileUtils.ln_s(final_path, compat, verbose: true)
    end
  end

  File.write('force-unsafe-io', '/etc/dpkg/dpkg.cfg.d/00_unsafeio')

  File.open('/etc/dpkg/dpkg.cfg.d/00_paths', 'w') do |file|
    # Do not install locales other than en/en_US.
    # Do not install manpages, infopages, groffpages.
    # Do not install docs.
    # NB: manpage first level items are kept via dpkg as it'd break openjdk8
    #   when the man1/ subdir is missing.
    path = {
      rxcludes: %w[
        /usr/share/locale/**/**
        /usr/share/man/**/**
        /usr/share/info/**/**
        /usr/share/groff/**/**
        /usr/share/doc/**/**
        /usr/share/ri/**/**
      ],
      excludes: %w[
        /usr/share/locale/*
        /usr/share/man/*
        /usr/share/info/*
        /usr/share/groff/*
        /usr/share/doc/*
        /usr/share/ri/*
      ],
      includes: %w[
        /usr/share/locale/en
        /usr/share/locale/en_US
        /usr/share/locale/locale.alias
      ]
    }
    path[:excludes].each { |e| file.puts("path-exclude=#{e}") }
    path[:includes].each { |i| file.puts("path-include=#{i}") }
    # Docker upstream images exclude all manpages already, which in turn
    # prevents the directories from appearing which then results in openjdk8
    # failing to install due to the missing dirs. Make sure we have at least
    # man1
    FileUtils.mkpath('/usr/share/man/man1')
    path[:rxcludes].each do |ruby_exclude|
      Dir.glob(ruby_exclude).each do |match|
        next if path[:includes].any? { |i| File.fnmatch(i, match) }
        next unless File.exist?(match)
        # Do not delete directories, it can screw up postinst assumptions.
        # For example openjdk8 will attempt to symlink to share/man/man1/ which
        # is not properly guarded, so it would fail postinst if the dir was
        # removed.
        next if File.directory?(match)

        FileUtils.rm_f(match, verbose: true)
      end
    end
  end

  # Force eatmydata on the installation binaries to completely bypass fsyncs.
  # This gives a 20% speed improvement on installing plasma-desktop+deps. That
  # is ~1 minute!
  %w[dpkg apt-get apt].each do |bin|
    file = "/usr/bin/#{bin}"
    next if File.exist?("#{file}.distrib") # Already diverted

    File.open("#{file}.pangea", File::RDWR | File::CREAT, 0o755) do |f|
      f.write(<<-SCRIPT)
#!/bin/sh
/usr/bin/eatmydata #{bin}.distrib "$@"
SCRIPT
    end
    system('dpkg-divert', '--local', '--rename', '--add', file) || raise
    File.symlink("#{file}.pangea", file)
  end

  # Turn fc-cache into a dud to prevent cache generation. Utterly pointless
  # in a build environment.
  %w[fc-cache].each do |bin|
    file = "/usr/bin/#{bin}"
    next if File.exist?("#{file}.distrib") # Already diverted

    system('dpkg-divert', '--local', '--rename', '--add', file) || raise
    # Fuck you dpkg. Fuck you so much.
    FileUtils.mv(file, "#{file}.distrib") if File.exist?(file)
    File.symlink('/bin/true', file)
  end

  # Install a fake fonts-noto CJK to bypass it's incredibly long unpack. Given
  # the size of the package it takes *seconds* to unpack but in CI environments
  # it adds no value.
  install_fake_pkg('fonts-noto-cjk')

  # Runs database update on apt-update (unnecessary slow down) and
  # that update also has opportunity to fail by the looks of it.
  install_fake_pkg('command-not-found')

  # FIXME: drop this. temporary undo for fake man-db
  Apt.purge('man-db')
  Apt.install('man-db')

  # Disable man-db; utterly useless at buildtime. mind that lintian requires
  # an actual man-db package to be installed though, so we can't fake it here!
  FileUtils.rm_rf('/var/lib/man-db/auto-update', verbose: true)

  # Ubuntu's language-pack-en-base calls this internally, since this is
  # unavailable on Debian, call it manually.
  locale_tag = "#{ENV.fetch('LANG')} UTF-8"
  File.open('/etc/locale.gen', 'a+') do |f|
    f.puts(locale_tag) unless f.any? { |l| l.start_with?(locale_tag) }
  end
  sh '/usr/sbin/locale-gen --keep-existing --no-purge --lang en'
  sh "update-locale LANG=#{ENV.fetch('LANG')}"

  # Prevent xapian from slowing down the test.
  # Install a fake package to prevent it from installing and doing anything.
  # This does render it non-functional but since we do not require the database
  # anyway this is the apparently only way we can make sure that it doesn't
  # create its stupid database. The CI hosts have really bad IO performance
  # making a full index take more than half an hour.
  install_fake_pkg('apt-xapian-index')

  uname = 'jenkins'
  uid = 100_000
  gname = 'jenkins'
  gid = 120

  group_exist = false
  Etc.group do |group|
    if group.name == gname
      group_exist = true
      break
    end
  end

  user_exist = false
  Etc.passwd do |user|
    if user.name == uname
      user_exist = true
      break
    end
  end

  sh "addgroup --system --gid #{gid} #{gname}" unless group_exist
  unless user_exist
    sh "adduser --system --home #{home} --uid #{uid} --ingroup #{gname}" \
       " --disabled-password #{uname}"
  end

  # Add the new jenkins user the sudoers so we can run as jenkins and elevate
  # if and when necessary.
  File.open("/etc/sudoers.d/#{uid}-#{uname}", 'w', 0o440) do |f|
    f.puts('jenkins ALL=(ALL) NOPASSWD: ALL')
  end

  custom_version_id # Add a custom version_id in os-release for DCI
  deployment_cleanup
end

# NB: Try to only add new stuff above the deployment task. It is so long and
# unwieldy that it'd be hard to find the end of it if you add stuff below it.
