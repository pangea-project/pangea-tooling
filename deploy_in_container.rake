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
  Dir.chdir(home) do
    # Clean up legacy things
    FileUtils.rm_rf(%w(.gem .rvm))
  end

  # Deploy ci-tooling and bundle. We later use internal libraries to provision
  # so we need all dependencies met as early as possible in the process.
  # FIXME: copy from above
  tooling_path = File.join(home, 'tooling-pending')
  final_path = File.join(home, 'ci-tooling')
  Dir.chdir(tooling_path) do
    begin
      Gem::Specification.find_by_name('bundler')
      sh 'gem update bundler'
    rescue Gem::LoadError
      sh 'gem install bundler'
    end
    system('bundle install --no-cache --local --frozen --system --without development test')
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
                  language-pack-en-base))

  sh "update-locale LANG=#{ENV.fetch('LANG')}"

  # Prevent xapian from slowing down the test.
  # Install a fake package to prevent it from installing and doing anything.
  # This does render it non-functional but since we do not require the database
  # anyway this is the apparently only way we can make sure that it doesn't
  # create its stupid database. The CI hosts have really bad IO performance making
  # a full index take more than half an hour.
  install_fake_pkg('apt-xapian-index')

  # FIXME: it would be much more reasonable to provision via chef-single...
  require 'etc'

  uname = 'jenkins'
  uid = 100000
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

  end
end
