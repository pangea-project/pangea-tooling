# frozen_string_literal: true
#
# Copyright (C) 2015-2017 Harald Sitter <sitter@kde.org>
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

require_relative 'lib/rake/bundle'
require_relative 'ci-tooling/lib/nci'

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
          python-launchpadlib ubuntu-dev-tools gnome-pkg-tools git dh-systemd
          zlib1g-dev python-paramiko sudo locales mercurial pxz aptitude
          autotools-dev cdbs dh-autoreconf germinate gnupg2
          gobject-introspection sphinx-common po4a pep8 pyflakes ppp-dev dh-di
          libgirepository1.0-dev libglib2.0-dev bash-completion
          python3-setuptools python3-setuptools-scm python-setuptools python-setuptools-scm dkms
          mozilla-devscripts libffi-dev subversion libssl-dev libcurl4-gnutls-dev
          libhttp-parser-dev javahelper rsync].freeze + CORE_RUNTIME_DEPS

# FIXME: code copy from install_check
def install_fake_pkg(name)
  require_relative 'ci-tooling/lib/dpkg'
  Dir.mktmpdir do |tmpdir|
    Dir.chdir(tmpdir) do
      FileUtils.mkpath("#{name}/DEBIAN")
      File.write("#{name}/DEBIAN/control", <<-CONTROL.gsub(/^\s+/, ''))
        Package: #{name}
        Version: 999:999
        Architecture: all
        Maintainer: Harald Sitter <sitter@kde.org>
        Description: fake override package for ci install checks
      CONTROL
      system("dpkg-deb -b #{name} #{name}.deb")
      DPKG.dpkg(['-i', "#{name}.deb"])
    end
  end
end

def custom_version_id
  require_relative 'ci-tooling/lib/dci'
  return unless DCI.series.keys.include?(DIST)

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

# openqa
task :deploy_openqa do
  # Only openqa on neon dists and if explicitly enabled.
  next unless NCI.series.keys.include?(DIST) &&
              ENV.include?('PANGEA_PROVISION_AUTOINST')
  Dir.mktmpdir do |tmpdir|
    system 'git clone --depth 1 ' \
       "https://github.com/apachelogger/kde-os-autoinst #{tmpdir}/"
    Dir.chdir('/opt') { sh "#{tmpdir}/bin/install.rb" }
  end
end

desc 'deploy inside the container'
task :deploy_in_container => %i[align_ruby deploy_openqa] do
  home = '/var/lib/jenkins'
  # Deploy ci-tooling and bundle. We later use internal libraries to provision
  # so we need all dependencies met as early as possible in the process.
  # FIXME: copy from above
  tooling_path = '/tooling-pending'
  final_path = '/tooling'
  final_ci_tooling_compat_path = File.join(home, 'tooling')
  final_ci_tooling_compat_compat_path = File.join(home, 'ci-tooling')

  File.write("#{Dir.home}/.gemrc", <<-EOF)
install: --no-document
update: --no-document
EOF

  Dir.chdir(tooling_path) do
    begin
      Gem::Specification.find_by_name('bundler')
      # don't update bundler while 1.16.0 has bugs
      # sh 'gem update bundler'
    rescue Gem::LoadError
      sh 'gem uninstall -x bundler --version \'~>1.16.0\' || true'
      sh 'bundle --version'
      sh 'gem install bundler --version \'~>1.15.0\''
    end

    bundle_args = ['install']
    bundle_args << "--jobs=#{[Etc.nprocessors / 2, 1].max}"
    bundle_args << '--local'
    bundle_args << '--no-cache'
    bundle_args << '--frozen'
    bundle_args << '--system'
    bundle_args << '--without' << 'development' << 'test'
    bundle(*bundle_args)

    # Clean up now unused gems. This prevents unused versions of a gem
    # lingering in the image blowing up its size.
    clean_args = ['clean']
    clean_args << '--verbose'
    clean_args << '--force' # Force system clean!
    bundle(*clean_args)

    # Trap common exit signals to make sure the ownership of the forwarded
    # volume is correct once we are done.
    # Otherwise it can happen that bundler left root owned artifacts behind
    # and the folder becomes undeletable.
    %w[EXIT HUP INT QUIT TERM].each do |signal|
      Signal.trap(signal) do
        next unless Etc.passwd { |u| break true if u.name == 'jenkins' }
        FileUtils.chown_R('jenkins', 'jenkins', tooling_path, verbose: true,
                                                              force: true)
      end
    end

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
      FileUtils.ln_s("#{final_path}/ci-tooling", compat, verbose: true)
    end
  end

  require_relative 'ci-tooling/lib/apt'

  File.write('force-unsafe-io', '/etc/dpkg/dpkg.cfg.d/00_unsafeio')

  File.open('/etc/dpkg/dpkg.cfg.d/00_paths', 'w') do |file|
    # Do not install locales other than en/en_US.
    # Do not install manpages, infopages, groffpages.
    # Do not install docs.
    path = {
      rxcludes: %w[
        /usr/share/locale/**/**
        /usr/share/man/**/**
        /usr/share/info/**/**
        /usr/share/groff/**/**
        /usr/share/doc/**/**
      ],
      excludes: %w[
        /usr/share/locale/*
        /usr/share/man/*
        /usr/share/info/*
        /usr/share/groff/*
        /usr/share/doc/*
      ],
      includes: %w[
        /usr/share/locale/en
        /usr/share/locale/en_US
        /usr/share/locale/locale.alias
      ]
    }
    path[:excludes].each { |e| file.write("path-exclude=#{e}") }
    path[:includes].each { |i| file.write("path-include=#{i}") }
    path[:rxcludes].each do |ruby_exclude|
      Dir.glob(ruby_exclude).each do |match|
        next if path[:includes].any? { |i| File.fnmatch(i, match) }
        next unless File.exist?(match)
        FileUtils.rm_rf(match)
      end
    end
  end

  Apt.install(*EARLY_DEPS) || raise

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

  require_relative 'ci-tooling/lib/retry'
  Retry.retry_it(times: 5, sleep: 8) do
    # NOTE: apt.rb automatically runs update the first time it is used.
    raise 'Dist upgrade failed' unless Apt.dist_upgrade
    raise 'Apt install failed' unless Apt.install(*DEPS)
    raise 'Autoremove failed' unless Apt.autoremove(args: '--purge')
    raise 'Clean failed' unless Apt.clean
  end

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

  # Add a custom version_id in os-release for DCI
  custom_version_id

  # Ultimate clean up
  #  Semi big logs
  File.write('/var/log/lastlog', '')
  File.write('/var/log/faillog', '')
  File.write('/var/log/dpkg.log', '')
  File.write('/var/log/apt/term.log', '')
  cleanup_rubies
end

desc 'Upgrade to newer ruby if required'
task :align_ruby do
  FileUtils.rm_rf('/tmp/kitchen') # Instead of messing with pulls, just clone.
  sh format('git clone --depth 1 %s %s',
            'https://github.com/blue-systems/pangea-kitchen.git',
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
    ENV['ALIGN_RUBY_EXEC'] = 'true'
    # Reload ourself via new rake
    exec('rake', *ARGV)
  else # installer crashed or other unexpected error.
    raise 'Error while aligning ruby version through pangea-kitchen'
  end
end
