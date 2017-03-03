require 'etc'
require 'fileutils'
require 'tmpdir'
require 'open-uri'

require_relative 'lib/rake/bundle'

DEPS = %w(xz-utils dpkg-dev dput debhelper pkg-kde-tools devscripts
          python-launchpadlib ubuntu-dev-tools gnome-pkg-tools git dh-systemd
          zlib1g-dev python-paramiko sudo locales mercurial pxz aptitude
          autotools-dev cdbs dh-autoreconf germinate gobject-introspection
          sphinx-common po4a pep8 pyflakes ppp-dev dh-di libgirepository1.0-dev
          libglib2.0-dev bash-completion python3-setuptools dkms
          mozilla-devscripts libffi-dev).freeze

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
        Description: fake override package for kubuntu ci install checks
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

    # Trap common exit signals to make sure the ownership of the forwarded
    # volume is correct once we are done.
    # Otherwise it can happen that bundler left root owned artifacts behind
    # and the folder becomes undeletable.
    %w(EXIT HUP INT QUIT TERM).each do |signal|
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
      rxcludes: %w(
        /usr/share/locale/**/**
        /usr/share/man/**/**
        /usr/share/info/**/**
        /usr/share/groff/**/**
        /usr/share/doc/**/**
      ),
      excludes: %w(
        /usr/share/locale/*
        /usr/share/man/*
        /usr/share/info/*
        /usr/share/groff/*
        /usr/share/doc/*
      ),
      includes: %w(
        /usr/share/locale/en
        /usr/share/locale/en_US
        /usr/share/locale/locale.alias
      )
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

  require_relative 'ci-tooling/lib/retry'
  Retry.retry_it(times: 5, sleep: 8) do
    # Use apt.
    raise 'Update failed' unless Apt.update
    raise 'Dist upgrade failed' unless Apt.dist_upgrade
    # FIXME: install reallly should allow array as input. that's not tested and
    # actually fails though
    raise 'Workaround failed' unless Apt.install(*%w(rsync))
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
  File.open("/etc/sudoers.d/#{uid}-#{uname}", 'w', 0440) do |f|
    f.puts('jenkins ALL=(ALL) NOPASSWD: ALL')
  end
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
