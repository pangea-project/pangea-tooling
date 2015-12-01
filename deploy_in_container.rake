require 'etc'
require 'fileutils'
require 'tmpdir'

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

desc 'deploy inside the container'
task :deploy_in_container do
  home = '/var/lib/jenkins'
  # Deploy ci-tooling and bundle. We later use internal libraries to provision
  # so we need all dependencies met as early as possible in the process.
  # FIXME: copy from above
  tooling_path = '/tooling-pending'
  final_path = File.join(home, 'ci-tooling')
  Dir.chdir(tooling_path) do
    begin
      Gem::Specification.find_by_name('bundler')
      sh 'gem update bundler'
    rescue Gem::LoadError
      sh 'gem install bundler'
    end
    bundle_args = []
    bundle_args << "--jobs=#{`nproc`.strip}"
    bundle_args << '--local'
    bundle_args << '--no-cache'
    bundle_args << '--frozen'
    bundle_args << '--system'
    bundle_args << '--without development test'
    sh "bundle install #{bundle_args.join(' ')}"

    # Trap common exit signals to make sure the ownership of the forwarded
    # volume is correct once we are done.
    # Otherwise it can happen that bundler left root owned artifacts behind
    # and the folder becomes undeletable.
    %w(EXIT HUP INT QUIT TERM).each do |signal|
      Signal.trap(signal) do
        next unless Etc.passwd { |u| break true if u.name == 'jenkins' }
        FileUtils.chown_R('jenkins', 'jenkins', tooling_path, verbose: true)
      end
    end

    Dir.chdir('ci-tooling') do
      FileUtils.rm_rf(final_path)
      FileUtils.mkpath(final_path)
      FileUtils.cp_r(Dir.glob('*'), final_path)
    end
  end

  require_relative 'ci-tooling/lib/apt'

  # Use apt.
  Apt.update
  Apt.dist_upgrade
  # FIXME: install reallly should allow array as input. that's not tested and
  # actually fails though
  Apt.install(*%w(xz-utils
                  dpkg-dev
                  dput
                  debhelper
                  pkg-kde-tools
                  devscripts
                  python-launchpadlib
                  ubuntu-dev-tools
                  git
                  dh-systemd
                  zlib1g-dev
                  python-paramiko
                  sudo
                  locales
                  pxz
                  aptitude
                  autotools-dev
                  cdbs
                  dh-autoreconf))
  Apt.clean

  # Ubuntu's language-pack-en-base calls this internally, since this is
  # unavailable on Debian, call it manually.
  sh "echo #{ENV.fetch('LANG')} UTF-8 >> /etc/locale.gen"
  sh '/usr/sbin/locale-gen --no-purge --lang en'
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
