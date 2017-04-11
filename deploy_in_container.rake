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

require 'date'
require 'etc'
require 'fileutils'
require 'tmpdir'
require 'open-uri'

require_relative 'lib/rake/bundle'

# Core is not here because it is required as a build-dep or anything but
# simply a runtime dep of the tooling.
CORE_RUNTIME_DEPS = %w[apt-transport-https].freeze
DEPS = %w[xz-utils dpkg-dev dput debhelper pkg-kde-tools devscripts
          python-launchpadlib ubuntu-dev-tools gnome-pkg-tools git dh-systemd
          zlib1g-dev python-paramiko sudo locales mercurial pxz aptitude
          autotools-dev cdbs dh-autoreconf germinate gnupg2
          gobject-introspection sphinx-common po4a pep8 pyflakes ppp-dev dh-di
          libgirepository1.0-dev libglib2.0-dev bash-completion
          python3-setuptools dkms mozilla-devscripts libffi-dev
          subversion].freeze + CORE_RUNTIME_DEPS

# FIXME: code copy from install_check
def install_fake_pkg(name)
  require_relative 'ci-tooling/lib/dpkg'
  Dir.mktmpdir do |tmpdir|
    Dir.chdir(tmpdir) do
      FileUtils.mkpath("#{name}/DEBIAN")
      File.write("#{name}/DEBIAN/control", <<-EOF.gsub(/^\s+/, ''))
        Package: #{name}
        Version: 999:999
        Architecture: all
        Maintainer: Harald Sitter <sitter@kde.org>
        Description: fake override package for ci install checks
      EOF
      system("dpkg-deb -b #{name} #{name}.deb")
      DPKG.dpkg(['-i', "#{name}.deb"])
    end
  end
end

def add_stretch_template
  File.open('/usr/share/python-apt/templates/Debian.info', 'a') do |f|
    f.write("\nSuite: stretch
RepositoryType: deb
BaseURI: http://http.us.debian.org/debian/
MatchURI: ftp[0-9]*\.([a-z]*\.){0,1}debian\.org
MirrorsFile: Debian.mirrors
Description: Debian testing
Component: main
CompDescription: Officially supported
Component: contrib
CompDescription: DFSG-compatible Software with Non-Free Dependencies
Component: non-free
CompDescription: Non-DFSG-compatible Software\n")
  end
end

desc 'deploy inside the container'
task :deploy_in_container => :align_ruby do
  home = '/var/lib/jenkins'
  # Deploy ci-tooling and bundle. We later use internal libraries to provision
  # so we need all dependencies met as early as possible in the process.
  # FIXME: copy from above
  tooling_path = '/tooling-pending'
  final_path = File.join(home, 'tooling')
  final_ci_tooling_compat_path = File.join(home, 'ci-tooling')

  File.write("#{Dir.home}/.gemrc", <<-EOF)
install: --no-document
update: --no-document
EOF

  Dir.chdir(tooling_path) do
    begin
      Gem::Specification.find_by_name('bundler')
      sh 'gem update bundler'
    rescue Gem::LoadError
      sh 'gem install bundler'
    end

    bundle_args = ['install']
    bundle_args << '--jobs=1'
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

    Dir.mktmpdir do |tmpdir|
      # We cannot bundle git gems through bundler as git bundles require
      # bundler rigging at runtime to get loaded as they are in a special path
      # not by default used by rubygems. This has the notable problem that our
      # in-container setup is super fucked up and cannot actually set up a
      # proper bundler rigging as it requires a Gemfile and whatnot.
      %w[https://anongit.kde.org/releaseme
         https://github.com/net-ssh/net-ssh].each do |repo|
        dir = "#{tmpdir}/#{File.basename(repo)}"
        system('git', 'clone', '--depth=1', repo, dir) || raise
        system('rake', 'install', chdir: dir) || raise
      end
    end

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
    FileUtils.cp_r(Dir.glob('*'), final_path)
    if File.symlink?(final_ci_tooling_compat_path)
      FileUtils.rm(final_ci_tooling_compat_path, verbose: true)
    elsif File.exist?(final_ci_tooling_compat_path)
      FileUtils.rm_r(final_ci_tooling_compat_path, verbose: true)
    end
    FileUtils.ln_s("#{final_path}/ci-tooling", final_ci_tooling_compat_path,
                   verbose: true)
  end

  require_relative 'ci-tooling/lib/apt'
  # Remove this once python-apt gets a Stretch template
  Apt.install('python-apt-common')
  add_stretch_template

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

  # Force eatmydata on the installation binaries to completely bypass fsyncs.
  # This gives a 20% speed improvement on installing plasma-desktop+deps. That
  # is ~1 minute!
  Apt.install('eatmydata') || raise
  %w[dpkg apt-get apt].each do |bin|
    file = "/usr/bin/#{bin}"
    next if File.exist?("#{file}.distrib") # Already diverted
    File.open("#{file}.pangea", File::RDWR | File::CREAT, 0o755) do |f|
      f.write(<<-EOF)
#!/bin/sh
/usr/bin/eatmydata #{bin}.distrib "$@"
EOF
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
    # Use apt.
    raise 'Update failed' unless Apt.update
    # Ubuntu pushed a makedev update. We can't dist-upgrade makedev as it
    # requires privileged access which we do not have on slaves. Hold it for 14
    # days, after that unhold so the dist-upgrades fails again.
    # At this point someone needs to determine if we want to wait longer or
    # devise a solution. To fix this the ubuntu base image we use needs to be
    # updated, which might happen soon. If not another approach is needed,
    # extending this workaround is only reasonable for up to 2017-05-01 after
    # that this needs a proper fix *at the latest*.
    if (DateTime.parse('2017-04-06 00:00:00') - DateTime.now).to_i <= 14
      raise 'Holding failed' unless system('apt-mark', 'hold', 'makedev')
    else
      raise 'Unholding failed' unless system('apt-mark', 'unhold', 'makedev')
    end
    raise 'Dist upgrade failed' unless Apt.dist_upgrade
    # FIXME: install reallly should allow array as input. that's not tested and
    # actually fails though
    raise 'Workaround failed' unless Apt.install(*%w[rsync])
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

  # Ultimate clean up
  #  Semi big logs
  File.write('/var/log/lastlog', '')
  File.write('/var/log/faillog', '')
  File.write('/var/log/dpkg.log', '')
  File.write('/var/log/apt/term.log', '')
  #  Gem cache and doc. Neither shoud be needed at runtime.
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/{cache,doc}/*'), verbose: true)
  #  libgit2 cmake build tree
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/gems/rugged-*/vendor/*/build'),
                  verbose: true)
  #  Other compiled extension artifacts not used at runtime
  FileUtils.rm_rf(Dir.glob('/var/lib/gems/*/gems/*/ext/*/*.{so,o}'),
                  verbose: true)
end

RUBY_2_3_1 = '/tmp/2.3.1'.freeze
RUBY_2_3_1_URL = 'https://raw.githubusercontent.com/rbenv/ruby-build/master/share/ruby-build/2.3.1'.freeze

desc 'Upgrade to newer ruby if required'
task :align_ruby do
  puts "Ruby version #{RbConfig::CONFIG['MAJOR']}.#{RbConfig::CONFIG['MINOR']}"
  if RbConfig::CONFIG['MAJOR'].to_i <= 2 && RbConfig::CONFIG['MINOR'].to_i < 2
    puts 'Bootstraping ruby'
    system('apt-get -y install ruby-build')
    File.write(RUBY_2_3_1, open(RUBY_2_3_1_URL).read)
    raise 'Failed to update ruby to 2.3.1' unless
      system("ruby-build #{RUBY_2_3_1} /usr/local")
    puts 'Ruby bootstrapped, please run deployment again'
    exit 0
  else
    puts 'Using system ruby'
  end
end
